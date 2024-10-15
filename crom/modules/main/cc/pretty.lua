local expect = require "cc.expect"
local expect, field = expect.expect, expect.field
local type, getmetatable, setmetatable, colours, str_write, tostring = type, getmetatable, setmetatable, colours, write, tostring
local debug_info, debug_local = debug.getinfo, debug.getlocal
local function append(out, value)
    local n = out.n + 1
    out[n], out.n = value, n
end
local Doc = { }
local function mk_doc(tbl) return setmetatable(tbl, Doc) end
local empty = mk_doc({ tag = "nil" })
local space = mk_doc({ tag = "text", text = " " })
local line = mk_doc({ tag = "line", flat = empty })
local space_line = mk_doc({ tag = "line", flat = space })
local text_cache = { [""] = empty, [" "] = space, ["\n"] = space_line }
local function mk_text(text, colour)
    return text_cache[text] or setmetatable({ tag = "text", text = text, colour = colour }, Doc)
end
local function text(text, colour)
    expect(1, text, "string")
    expect(2, colour, "number", "nil")
    local cached = text_cache[text]
    if cached then return cached end
    local new_line = text:find("\n", 1)
    if not new_line then return mk_text(text, colour) end
    local doc = setmetatable({ tag = "concat", n = 0 }, Doc)
    if new_line ~= 1 then append(doc, mk_text(text:sub(1, new_line - 1), colour)) end
    new_line = new_line + 1
    while true do
        local next_line = text:find("\n", new_line)
        append(doc, space_line)
        if not next_line then
            if new_line <= #text then append(doc, mk_text(text:sub(new_line), colour)) end
            return doc
        else
            if new_line <= next_line - 1 then
                append(doc, mk_text(text:sub(new_line, next_line - 1), colour))
            end
            new_line = next_line + 1
        end
    end
end
local function concat(...)
    local args = table.pack(...)
    for i = 1, args.n do
        if type(args[i]) == "string" then args[i] = text(args[i]) end
        if getmetatable(args[i]) ~= Doc then expect(i, args[i], "document") end
    end
    if args.n == 0 then return empty end
    if args.n == 1 then return args[1] end
    args.tag = "concat"
    return setmetatable(args, Doc)
end
Doc.__concat = concat 
local function nest(depth, doc)
    expect(1, depth, "number")
    if getmetatable(doc) ~= Doc then expect(2, doc, "document") end
    if depth <= 0 then error("depth must be a positive number", 2) end
    return setmetatable({ tag = "nest", depth = depth, doc }, Doc)
end
local function flatten(doc)
    if doc.flat then return doc.flat end
    local kind = doc.tag
    if kind == "nil" or kind == "text" then
        return doc
    elseif kind == "concat" then
        local out = setmetatable({ tag = "concat", n = doc.n }, Doc)
        for i = 1, doc.n do out[i] = flatten(doc[i]) end
        doc.flat, out.flat = out, out 
        return out
    elseif kind == "nest" then
        return flatten(doc[1])
    elseif kind == "group" then
        return doc[1]
    else
        error("Unknown doc " .. kind)
    end
end
local function group(doc)
    if getmetatable(doc) ~= Doc then expect(1, doc, "document") end
    if doc.tag == "group" then return doc end 
    local flattened = flatten(doc)
    if flattened == doc then return doc end 
    return setmetatable({ tag = "group", flattened, doc }, Doc)
end
local function get_remaining(doc, width)
    local kind = doc.tag
    if kind == "nil" or kind == "line" then
        return width
    elseif kind == "text" then
        return width - #doc.text
    elseif kind == "concat" then
        for i = 1, doc.n do
            width = get_remaining(doc[i], width)
            if width < 0 then break end
        end
        return width
    elseif kind == "group" or kind == "nest" then
        return get_remaining(kind[1])
    else
        error("Unknown doc " .. kind)
    end
end
local function write(doc, ribbon_frac)
    if getmetatable(doc) ~= Doc then expect(1, doc, "document") end
    expect(2, ribbon_frac, "number", "nil")
    local term = term
    local width, height = term.getSize()
    local ribbon_width = (ribbon_frac or 0.6) * width
    if ribbon_width < 0 then ribbon_width = 0 end
    if ribbon_width > width then ribbon_width = width end
    local def_colour = term.getTextColour()
    local current_colour = def_colour
    local function go(doc, indent, col)
        local kind = doc.tag
        if kind == "nil" then
            return col
        elseif kind == "text" then
            local doc_colour = doc.colour or def_colour
            if doc_colour ~= current_colour then
                term.setTextColour(doc_colour)
                current_colour = doc_colour
            end
            str_write(doc.text)
            return col + #doc.text
        elseif kind == "line" then
            local _, y = term.getCursorPos()
            if y < height then
                term.setCursorPos(indent + 1, y + 1)
            else
                term.scroll(1)
                term.setCursorPos(indent + 1, height)
            end
            return indent
        elseif kind == "concat" then
            for i = 1, doc.n do col = go(doc[i], indent, col) end
            return col
        elseif kind == "nest" then
            return go(doc[1], indent + doc.depth, col)
        elseif kind == "group" then
            if get_remaining(doc[1], math.min(width, ribbon_width + indent) - col) >= 0 then
                return go(doc[1], indent, col)
            else
                return go(doc[2], indent, col)
            end
        else
            error("Unknown doc " .. kind)
        end
    end
    local col = math.max(term.getCursorPos() - 1, 0)
    go(doc, 0, col)
    if current_colour ~= def_colour then term.setTextColour(def_colour) end
end
local function print(doc, ribbon_frac)
    if getmetatable(doc) ~= Doc then expect(1, doc, "document") end
    expect(2, ribbon_frac, "number", "nil")
    write(doc, ribbon_frac)
    str_write("\n")
end
local function render(doc, width, ribbon_frac)
    if getmetatable(doc) ~= Doc then expect(1, doc, "document") end
    expect(2, width, "number", "nil")
    expect(3, ribbon_frac, "number", "nil")
    local ribbon_width
    if width then
        ribbon_width = (ribbon_frac or 0.6) * width
        if ribbon_width < 0 then ribbon_width = 0 end
        if ribbon_width > width then ribbon_width = width end
    end
    local out = { n = 0 }
    local function go(doc, indent, col)
        local kind = doc.tag
        if kind == "nil" then
            return col
        elseif kind == "text" then
            append(out, doc.text)
            return col + #doc.text
        elseif kind == "line" then
            append(out, "\n" .. (" "):rep(indent))
            return indent
        elseif kind == "concat" then
            for i = 1, doc.n do col = go(doc[i], indent, col) end
            return col
        elseif kind == "nest" then
            return go(doc[1], indent + doc.depth, col)
        elseif kind == "group" then
            if not width or get_remaining(doc[1], math.min(width, ribbon_width + indent) - col) >= 0 then
                return go(doc[1], indent, col)
            else
                return go(doc[2], indent, col)
            end
        else
            error("Unknown doc " .. kind)
        end
    end
    go(doc, 0, 0)
    return table.concat(out, "", 1, out.n)
end
Doc.__tostring = render 
local keywords = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
    ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true,
    ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true,
  }
local comma = text(",")
local braces = text("{}")
local obrace, cbrace = text("{"), text("}")
local obracket, cbracket = text("["), text("] = ")
local function key_compare(a, b)
    local ta, tb = type(a), type(b)
    if ta == "string" then return tb ~= "string" or a < b
    elseif tb == "string" then return false
    end
    if ta == "number" then return tb ~= "number" or a < b end
    return false
end
local function show_function(fn, options)
    local info = debug_info and debug_info(fn, "Su")
    local name
    if options.function_source and info and info.short_src and info.linedefined and info.linedefined >= 1 then
        name = "function<" .. info.short_src .. ":" .. info.linedefined .. ">"
    else
        name = tostring(fn)
    end
    if options.function_args and info and info.what == "Lua" and info.nparams and debug_local then
        local args = {}
        for i = 1, info.nparams do args[i] = debug_local(fn, i) or "?" end
        if info.isvararg then args[#args + 1] = "..." end
        name = name .. "(" .. table.concat(args, ", ") .. ")"
    end
    return name
end
local function pretty_impl(obj, options, tracking)
    local obj_type = type(obj)
    if obj_type == "string" then
        local formatted = ("%q"):format(obj):gsub("\\\n", "\\n")
        return text(formatted, colours.red)
    elseif obj_type == "number" then
        return text(tostring(obj), colours.magenta)
    elseif obj_type == "function" then
        return text(show_function(obj, options), colours.lightGrey)
    elseif obj_type ~= "table" or tracking[obj] then
        return text(tostring(obj), colours.lightGrey)
    elseif getmetatable(obj) ~= nil and getmetatable(obj).__tostring then
        return text(tostring(obj))
    elseif next(obj) == nil then
        return braces
    else
        tracking[obj] = true
        local doc = setmetatable({ tag = "concat", n = 1, space_line }, Doc)
        local length, keys, keysn = #obj, {}, 1
        for k in pairs(obj) do
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > length then
                keys[keysn], keysn = k, keysn + 1
            end
        end
        table.sort(keys, key_compare)
        for i = 1, length do
            if i > 1 then append(doc, comma) append(doc, space_line) end
            append(doc, pretty_impl(obj[i], options, tracking))
        end
        for i = 1, keysn - 1 do
            if i > 1 or length >= 1 then append(doc, comma) append(doc, space_line) end
            local k = keys[i]
            local v = obj[k]
            if type(k) == "string" and not keywords[k] and k:match("^[%a_][%a%d_]*$") then
                append(doc, text(k .. " = "))
                append(doc, pretty_impl(v, options, tracking))
            else
                append(doc, obracket)
                append(doc, pretty_impl(k, options, tracking))
                append(doc, cbracket)
                append(doc, pretty_impl(v, options, tracking))
            end
        end
        tracking[obj] = nil
        return group(concat(obrace, nest(2, concat(table.unpack(doc, 1, doc.n))), space_line, cbrace))
    end
end
local function pretty(obj, options)
    expect(2, options, "table", "nil")
    options = options or {}
    local actual_options = {
        function_source = field(options, "function_source", "boolean", "nil") or false,
        function_args = field(options, "function_args", "boolean", "nil") or false,
    }
    return pretty_impl(obj, actual_options, {})
end
local function pretty_print(obj, options, ribbon_frac)
    expect(2, options, "table", "nil")
    options = options or {}
    expect(3, ribbon_frac, "number", "nil")
    return print(pretty(obj, options), ribbon_frac)
end
return {
    empty = empty,
    space = space,
    line = line,
    space_line = space_line,
    text = text,
    concat = concat,
    nest = nest,
    group = group,
    write = write,
    print = print,
    render = render,
    pretty = pretty,
    pretty_print = pretty_print,
}