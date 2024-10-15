local expect = dofile("crom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field
local wrap = dofile("crom/modules/main/cc/strings.lua").wrap
function slowWrite(text, rate)
    expect(2, rate, "number", "nil")
    rate = rate or 20
    if rate < 0 then
        error("Rate must be positive", 2)
    end
    local to_sleep = 1 / rate
    local wrapped_lines = wrap(tostring(text), (term.getSize()))
    local wrapped_str = table.concat(wrapped_lines, "\n")
    for n = 1, #wrapped_str do
        sleep(to_sleep)
        write(wrapped_str:sub(n, n))
    end
end
function slowPrint(sText, nRate)
    slowWrite(sText, nRate)
    print()
end
function formatTime(nTime, bTwentyFourHour)
    expect(1, nTime, "number")
    expect(2, bTwentyFourHour, "boolean", "nil")
    local sTOD = nil
    if not bTwentyFourHour then
        if nTime >= 12 then
            sTOD = "PM"
        else
            sTOD = "AM"
        end
        if nTime >= 13 then
            nTime = nTime - 12
        end
    end
    local nHour = math.floor(nTime)
    local nMinute = math.floor((nTime - nHour) * 60)
    if sTOD then
        return string.format("%d:%02d %s", nHour == 0 and 12 or nHour, nMinute, sTOD)
    else
        return string.format("%d:%02d", nHour, nMinute)
    end
end
local function makePagedScroll(_term, _nFreeLines)
    local nativeScroll = _term.scroll
    local nFreeLines = _nFreeLines or 0
    return function(_n)
        for _ = 1, _n do
            nativeScroll(1)
            if nFreeLines <= 0 then
                local _, h = _term.getSize()
                _term.setCursorPos(1, h)
                _term.write("Press any key to continue")
                os.pullEvent("key")
                _term.clearLine()
                _term.setCursorPos(1, h)
            else
                nFreeLines = nFreeLines - 1
            end
        end
    end
end
function pagedPrint(text, free_lines)
    expect(2, free_lines, "number", "nil")
    local oldTerm = term.current()
    local newTerm = {}
    for k, v in pairs(oldTerm) do
        newTerm[k] = v
    end
    newTerm.scroll = makePagedScroll(oldTerm, free_lines)
    term.redirect(newTerm)
    local result
    local ok, err = pcall(function()
        if text ~= nil then
            result = print(text)
        else
            result = print()
        end
    end)
    term.redirect(oldTerm)
    if not ok then
        error(err, 0)
    end
    return result
end
local function tabulateCommon(bPaged, ...)
    local tAll = table.pack(...)
    for i = 1, tAll.n do
        expect(i, tAll[i], "number", "table")
    end
    local w, h = term.getSize()
    local nMaxLen = w / 8
    for n, t in ipairs(tAll) do
        if type(t) == "table" then
            for nu, sItem in pairs(t) do
                local ty = type(sItem)
                if ty ~= "string" and ty ~= "number" then
                    error("bad argument #" .. n .. "." .. nu .. " (string expected, got " .. ty .. ")", 3)
                end
                nMaxLen = math.max(#tostring(sItem) + 1, nMaxLen)
            end
        end
    end
    local nCols = math.floor(w / nMaxLen)
    local nLines = 0
    local function newLine()
        if bPaged and nLines >= h - 3 then
            pagedPrint()
        else
            print()
        end
        nLines = nLines + 1
    end
    local function drawCols(_t)
        local nCol = 1
        for _, s in ipairs(_t) do
            if nCol > nCols then
                nCol = 1
                newLine()
            end
            local cx, cy = term.getCursorPos()
            cx = 1 + (nCol - 1) * nMaxLen
            term.setCursorPos(cx, cy)
            term.write(s)
            nCol = nCol + 1
        end
        print()
    end
    local previous_colour = term.getTextColour()
    for _, t in ipairs(tAll) do
        if type(t) == "table" then
            if #t > 0 then
                drawCols(t)
            end
        elseif type(t) == "number" then
            term.setTextColor(t)
        end
    end
    term.setTextColor(previous_colour)
end
function tabulate(...)
    return tabulateCommon(false, ...)
end
function pagedTabulate(...)
    return tabulateCommon(true, ...)
end
local g_tLuaKeywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}
local function inext(tbl, i)
    i = (i or 0) + 1
    local v = rawget(tbl, i)
    if v == nil then return nil else return i, v end
end
local serialize_infinity = math.huge
local function serialize_impl(t, tracking, indent, opts)
    local sType = type(t)
    if sType == "table" then
        if tracking[t] ~= nil then
            if tracking[t] == false then
                error("Cannot serialize table with repeated entries", 0)
            else
                error("Cannot serialize table with recursive entries", 0)
            end
        end
        tracking[t] = true
        local result
        if next(t) == nil then
            result = "{}"
        else
            local open, sub_indent, open_key, close_key, equal, comma = "{\n", indent .. "  ", "[ ", " ] = ", " = ", ",\n"
            if opts.compact then
                open, sub_indent, open_key, close_key, equal, comma = "{", "", "[", "]=", "=", ","
            end
            result = open
            local seen_keys = {}
            for k, v in inext, t do
                seen_keys[k] = true
                result = result .. sub_indent .. serialize_impl(v, tracking, sub_indent, opts) .. comma
            end
            for k, v in next, t do
                if not seen_keys[k] then
                    local sEntry
                    if type(k) == "string" and not g_tLuaKeywords[k] and string.match(k, "^[%a_][%a%d_]*$") then
                        sEntry = k .. equal .. serialize_impl(v, tracking, sub_indent, opts) .. comma
                    else
                        sEntry = open_key .. serialize_impl(k, tracking, sub_indent, opts) .. close_key .. serialize_impl(v, tracking, sub_indent, opts) .. comma
                    end
                    result = result .. sub_indent .. sEntry
                end
            end
            result = result .. indent .. "}"
        end
        if opts.allow_repetitions then
            tracking[t] = nil
        else
            tracking[t] = false
        end
        return result
    elseif sType == "string" then
        return string.format("%q", t)
    elseif sType == "number" then
        if t ~= t then 
            return "0/0"
        elseif t == serialize_infinity then
            return "1/0"
        elseif t == -serialize_infinity then
            return "-1/0"
        else
            return tostring(t)
        end
    elseif sType == "boolean" or sType == "nil" then
        return tostring(t)
    else
        error("Cannot serialize type " .. sType, 0)
    end
end
local function mk_tbl(str, name)
    local msg = "attempt to mutate textutils." .. name
    return setmetatable({}, {
        __newindex = function() error(msg, 2) end,
        __tostring = function() return str end,
    })
end
empty_json_array = mk_tbl("[]", "empty_json_array")
json_null = mk_tbl("null", "json_null")
local serializeJSONString
do
    local function hexify(c)
        return ("\\u00%02X"):format(c:byte())
    end
    local map = {
        ["\""] = "\\\"",
        ["\\"] = "\\\\",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    for i = 0, 0x1f do
        local c = string.char(i)
        if map[c] == nil then map[c] = hexify(c) end
    end
    serializeJSONString = function(s, options)
        if options and options.unicode_strings and s:find("[\x80-\xff]") then
            local retval = '"'
            for _, code in utf8.codes(s) do
                if code > 0xFFFF then
                    code = code - 0x10000
                    local high, low = bit32.extract(code, 10, 10) + 0xD800, bit32.extract(code, 0, 10) + 0xDC00
                    retval = retval .. ("\\u%04X\\u%04X"):format(high, low)
                elseif code <= 0x5C and map[string.char(code)] then 
                    retval = retval .. map[string.char(code)]
                elseif code < 0x20 or code >= 0x7F then
                    retval = retval .. ("\\u%04X"):format(code)
                else
                    retval = retval .. string.char(code)
                end
            end
            return retval .. '"'
        else
            return ('"%s"'):format(s:gsub("[\0-\x1f\"\\]", map):gsub("[\x7f-\xff]", hexify))
        end
    end
end
local function serializeJSONImpl(t, tracking, options)
    local sType = type(t)
    if t == empty_json_array then return "[]"
    elseif t == json_null then return "null"
    elseif sType == "table" then
        if tracking[t] ~= nil then
            if tracking[t] == false then
                error("Cannot serialize table with repeated entries", 0)
            else
                error("Cannot serialize table with recursive entries", 0)
            end
        end
        tracking[t] = true
        local result
        if next(t) == nil then
            result = "{}"
        else
            local sObjectResult = "{"
            local sArrayResult = "["
            local nObjectSize = 0
            local nArraySize = 0
            local largestArrayIndex = 0
            local bNBTStyle = options.nbt_style
            for k, v in pairs(t) do
                if type(k) == "string" then
                    local sEntry
                    if bNBTStyle then
                        sEntry = tostring(k) .. ":" .. serializeJSONImpl(v, tracking, options)
                    else
                        sEntry = serializeJSONString(k, options) .. ":" .. serializeJSONImpl(v, tracking, options)
                    end
                    if nObjectSize == 0 then
                        sObjectResult = sObjectResult .. sEntry
                    else
                        sObjectResult = sObjectResult .. "," .. sEntry
                    end
                    nObjectSize = nObjectSize + 1
                elseif type(k) == "number" and k > largestArrayIndex then 
                    largestArrayIndex = k
                end
            end
            for k = 1, largestArrayIndex, 1 do 
                local sEntry
                if t[k] == nil then 
                    sEntry = "null"
                else 
                    sEntry = serializeJSONImpl(t[k], tracking, options)
                end
                if nArraySize == 0 then
                    sArrayResult = sArrayResult .. sEntry
                else
                    sArrayResult = sArrayResult .. "," .. sEntry
                end
                nArraySize = nArraySize + 1
            end
            sObjectResult = sObjectResult .. "}"
            sArrayResult = sArrayResult .. "]"
            if nObjectSize > 0 or nArraySize == 0 then
                result = sObjectResult
            else
                result = sArrayResult
            end
        end
        if options.allow_repetitions then
            tracking[t] = nil
        else
            tracking[t] = false
        end
        return result
    elseif sType == "string" then
        return serializeJSONString(t, options)
    elseif sType == "number" or sType == "boolean" then
        return tostring(t)
    else
        error("Cannot serialize type " .. sType, 0)
    end
end
local unserialise_json
do
    local sub, find, match, concat, tonumber = string.sub, string.find, string.match, table.concat, tonumber
    local function skip(str, pos)
        local _, last = find(str, "^[ \n\r\t]+", pos)
        if last then return last + 1 else return pos end
    end
    local escapes = {
        ["b"] = '\b', ["f"] = '\f', ["n"] = '\n', ["r"] = '\r', ["t"] = '\t',
        ["\""] = "\"", ["/"] = "/", ["\\"] = "\\",
    }
    local mt = {}
    local function error_at(pos, msg, ...)
        if select('#', ...) > 0 then msg = msg:format(...) end
        error(setmetatable({ pos = pos, msg = msg }, mt))
    end
    local function expected(pos, actual, exp)
        if actual == "" then actual = "end of input" else actual = ("%q"):format(actual) end
        error_at(pos, "Unexpected %s, expected %s.", actual, exp)
    end
    local function parse_string(str, pos, terminate)
        local buf, n = {}, 1
        local char_pat = "^[ !#-[%]^-\255]+"
        if terminate == "'" then char_pat = "^[ -&(-[%]^-\255]+" end
        while true do
            local c = sub(str, pos, pos)
            if c == "" then error_at(pos, "Unexpected end of input, expected '\"'.") end
            if c == terminate then break end
            if c == "\\" then
                c = sub(str, pos + 1, pos + 1)
                if c == "" then error_at(pos, "Unexpected end of input, expected escape sequence.") end
                if c == "u" then
                    local num_str = match(str, "^%x%x%x%x", pos + 2)
                    if not num_str then error_at(pos, "Malformed unicode escape %q.", sub(str, pos + 2, pos + 5)) end
                    buf[n], n, pos = utf8.char(tonumber(num_str, 16)), n + 1, pos + 6
                else
                    local unesc = escapes[c]
                    if not unesc then error_at(pos + 1, "Unknown escape character %q.", c) end
                    buf[n], n, pos = unesc, n + 1, pos + 2
                end
            elseif c >= " " then
                local _, finish = find(str, char_pat, pos)
                buf[n], n = sub(str, pos, finish), n + 1
                pos = finish + 1
            else
                error_at(pos + 1, "Unescaped whitespace %q.", c)
            end
        end
        return concat(buf, "", 1, n - 1), pos + 1
    end
    local num_types = { b = true, B = true, s = true, S = true, l = true, L = true, f = true, F = true, d = true, D = true }
    local function parse_number(str, pos, opts)
        local _, last, num_str = find(str, '^(-?%d+%.?%d*[eE]?[+-]?%d*)', pos)
        local val = tonumber(num_str)
        if not val then error_at(pos, "Malformed number %q.", num_str) end
        if opts.nbt_style and num_types[sub(str, last + 1, last + 1)] then return val, last + 2 end
        return val, last + 1
    end
    local function parse_ident(str, pos)
        local _, last, val = find(str, '^([%a][%w_]*)', pos)
        return val, last + 1
    end
    local arr_types = { I = true, L = true, B = true }
    local function decode_impl(str, pos, opts)
        local c = sub(str, pos, pos)
        if c == '"' then return parse_string(str, pos + 1, '"')
        elseif c == "'" and opts.nbt_style then return parse_string(str, pos + 1, "\'")
        elseif c == "-" or c >= "0" and c <= "9" then return parse_number(str, pos, opts)
        elseif c == "t" then
            if sub(str, pos + 1, pos + 3) == "rue" then return true, pos + 4 end
        elseif c == 'f' then
            if sub(str, pos + 1, pos + 4) == "alse" then return false, pos + 5 end
        elseif c == 'n' then
            if sub(str, pos + 1, pos + 3) == "ull" then
                if opts.parse_null then
                    return json_null, pos + 4
                else
                    return nil, pos + 4
                end
            end
        elseif c == "{" then
            local obj = {}
            pos = skip(str, pos + 1)
            c = sub(str, pos, pos)
            if c == "" then return error_at(pos, "Unexpected end of input, expected '}'.") end
            if c == "}" then return obj, pos + 1 end
            while true do
                local key, value
                if c == "\"" then key, pos = parse_string(str, pos + 1, "\"")
                elseif opts.nbt_style then key, pos = parse_ident(str, pos)
                else return expected(pos, c, "object key")
                end
                pos = skip(str, pos)
                c = sub(str, pos, pos)
                if c ~= ":" then return expected(pos, c, "':'") end
                value, pos = decode_impl(str, skip(str, pos + 1), opts)
                obj[key] = value
                pos = skip(str, pos)
                c = sub(str, pos, pos)
                if c == "}" then break
                elseif c == "," then pos = skip(str, pos + 1)
                else return expected(pos, c, "',' or '}'")
                end
                c = sub(str, pos, pos)
            end
            return obj, pos + 1
        elseif c == "[" then
            local arr, n = {}, 1
            pos = skip(str, pos + 1)
            c = sub(str, pos, pos)
            if arr_types[c] and sub(str, pos + 1, pos + 1) == ";" and opts.nbt_style then
                pos = skip(str, pos + 2)
                c = sub(str, pos, pos)
            end
            if c == "" then return expected(pos, c, "']'") end
            if c == "]" then
                if opts.parse_empty_array ~= false then
                    return empty_json_array, pos + 1
                else
                    return {}, pos + 1
                end
            end
            while true do
                n, arr[n], pos = n + 1, decode_impl(str, pos, opts)
                pos = skip(str, pos)
                c = sub(str, pos, pos)
                if c == "]" then break
                elseif c == "," then pos = skip(str, pos + 1)
                else return expected(pos, c, "',' or ']'")
                end
            end
            return arr, pos + 1
        elseif c == "" then error_at(pos, 'Unexpected end of input.')
        end
        error_at(pos, "Unexpected character %q.", c)
    end
    unserialise_json = function(s, options)
        expect(1, s, "string")
        expect(2, options, "table", "nil")
        if options then
            field(options, "nbt_style", "boolean", "nil")
            field(options, "parse_null", "boolean", "nil")
            field(options, "parse_empty_array", "boolean", "nil")
        else
            options = {}
        end
        local ok, res, pos = pcall(decode_impl, s, skip(s, 1), options)
        if not ok then
            if type(res) == "table" and getmetatable(res) == mt then
                return nil, ("Malformed JSON at position %d: %s"):format(res.pos, res.msg)
            end
            error(res, 0)
        end
        pos = skip(s, pos)
        if pos <= #s then
            return nil, ("Malformed JSON at position %d: Unexpected trailing character %q."):format(pos, sub(s, pos, pos))
        end
        return res
    end
end
function serialize(t, opts)
    local tTracking = {}
    expect(2, opts, "table", "nil")
    if opts then
        field(opts, "compact", "boolean", "nil")
        field(opts, "allow_repetitions", "boolean", "nil")
    else
        opts = {}
    end
    return serialize_impl(t, tTracking, "", opts)
end
serialise = serialize 
function unserialize(s)
    expect(1, s, "string")
    local func = load("return " .. s, "unserialize", "t", {})
    if func then
        local ok, result = pcall(func)
        if ok then
            return result
        end
    end
    return nil
end
unserialise = unserialize 
function serializeJSON(t, options)
    expect(1, t, "table", "string", "number", "boolean")
    expect(2, options, "table", "boolean", "nil")
    if type(options) == "boolean" then
        options = { nbt_style = options }
    elseif type(options) == "table" then
        field(options, "nbt_style", "boolean", "nil")
        field(options, "unicode_strings", "boolean", "nil")
        field(options, "allow_repetitions", "boolean", "nil")
    else
        options = {}
    end
    local tTracking = {}
    return serializeJSONImpl(t, tTracking, options)
end
serialiseJSON = serializeJSON 
unserializeJSON = unserialise_json
unserialiseJSON = unserialise_json
function urlEncode(str)
    expect(1, str, "string")
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^A-Za-z0-9 %-%_%.])", function(c)
            local n = string.byte(c)
            if n < 128 then
                return string.format("%%%02X", n)
            else
                return
                    string.format("%%%02X", 192 + bit32.band(bit32.arshift(n, 6), 31)) ..
                    string.format("%%%02X", 128 + bit32.band(n, 63))
            end
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end
local tEmpty = {}
function complete(sSearchText, tSearchTable)
    expect(1, sSearchText, "string")
    expect(2, tSearchTable, "table", "nil")
    if g_tLuaKeywords[sSearchText] then return tEmpty end
    local nStart = 1
    local nDot = string.find(sSearchText, ".", nStart, true)
    local tTable = tSearchTable or _ENV
    while nDot do
        local sPart = string.sub(sSearchText, nStart, nDot - 1)
        local value = tTable[sPart]
        if type(value) == "table" then
            tTable = value
            nStart = nDot + 1
            nDot = string.find(sSearchText, ".", nStart, true)
        else
            return tEmpty
        end
    end
    local nColon = string.find(sSearchText, ":", nStart, true)
    if nColon then
        local sPart = string.sub(sSearchText, nStart, nColon - 1)
        local value = tTable[sPart]
        if type(value) == "table" then
            tTable = value
            nStart = nColon + 1
        else
            return tEmpty
        end
    end
    local sPart = string.sub(sSearchText, nStart)
    local nPartLength = #sPart
    local tResults = {}
    local tSeen = {}
    while tTable do
        for k, v in pairs(tTable) do
            if not tSeen[k] and type(k) == "string" then
                if string.find(k, sPart, 1, true) == 1 then
                    if not g_tLuaKeywords[k] and string.match(k, "^[%a_][%a%d_]*$") then
                        local sResult = string.sub(k, nPartLength + 1)
                        if nColon then
                            if type(v) == "function" then
                                table.insert(tResults, sResult .. "(")
                            elseif type(v) == "table" then
                                local tMetatable = getmetatable(v)
                                if tMetatable and (type(tMetatable.__call) == "function" or  type(tMetatable.__call) == "table") then
                                    table.insert(tResults, sResult .. "(")
                                end
                            end
                        else
                            if type(v) == "function" then
                                sResult = sResult .. "("
                            elseif type(v) == "table" and next(v) ~= nil then
                                sResult = sResult .. "."
                            end
                            table.insert(tResults, sResult)
                        end
                    end
                end
            end
            tSeen[k] = true
        end
        local tMetatable = getmetatable(tTable)
        if tMetatable and type(tMetatable.__index) == "table" then
            tTable = tMetatable.__index
        else
            tTable = nil
        end
    end
    table.sort(tResults)
    return tResults
end