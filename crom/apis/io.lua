local expect, type_of = dofile("crom/modules/main/cc/expect.lua").expect, _G.type
local function checkResult(handle, ...)
    if ... == nil and handle._autoclose and not handle._closed then handle:close() end
    return ...
end
local handleMetatable
handleMetatable = {
    __name = "FILE*",
    __tostring = function(self)
        if self._closed then
            return "file (closed)"
        else
            local hash = tostring(self._handle):match("table: (%x+)")
            return "file (" .. hash .. ")"
        end
    end,
    __index = {
        close = function(self)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if handle.close then
                self._closed = true
                handle.close()
                return true
            else
                return nil, "attempt to close standard stream"
            end
        end,
        flush = function(self)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if handle.flush then handle.flush() end
            return true
        end,
        lines = function(self, ...)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if not handle.read then return nil, "file is not readable" end
            local args = table.pack(...)
            return function()
                if self._closed then error("file is already closed", 2) end
                return checkResult(self, self:read(table.unpack(args, 1, args.n)))
            end
        end,
        read = function(self, ...)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if not handle.read and not handle.readLine then return nil, "Not opened for reading" end
            local n = select("#", ...)
            local output = {}
            for i = 1, n do
                local arg = select(i, ...)
                local res
                if type_of(arg) == "number" then
                    if handle.read then res = handle.read(arg) end
                elseif type_of(arg) == "string" then
                    local format = arg:gsub("^%*", ""):sub(1, 1)
                    if format == "l" then
                        if handle.readLine then res = handle.readLine() end
                    elseif format == "L" and handle.readLine then
                        if handle.readLine then res = handle.readLine(true) end
                    elseif format == "a" then
                        if handle.readAll then res = handle.readAll() or "" end
                    elseif format == "n" then
                        res = nil 
                    else
                        error("bad argument #" .. i .. " (invalid format)", 2)
                    end
                else
                    error("bad argument #" .. i .. " (string expected, got " .. type_of(arg) .. ")", 2)
                end
                output[i] = res
                if not res then break end
            end
            if n == 0 and handle.readLine then return handle.readLine() end
            return table.unpack(output, 1, n)
        end,
        seek = function(self, whence, offset)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if not handle.seek then return nil, "file is not seekable" end
            return handle.seek(whence, offset)
        end,
        setvbuf = function(self, mode, size) end,
        write = function(self, ...)
            if type_of(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type_of(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end
            local handle = self._handle
            if not handle.write then return nil, "file is not writable" end
            for i = 1, select("#", ...) do
                local arg = select(i, ...)
                expect(i, arg, "string", "number")
                handle.write(arg)
            end
            return self
        end,
    },
}
local function make_file(handle)
    return setmetatable({ _handle = handle }, handleMetatable)
end
local defaultInput = make_file({ readLine = _G.read })
local defaultOutput = make_file({ write = _G.write })
local defaultError = make_file({
    write = function(...)
        local oldColour
        if term.isColour() then
            oldColour = term.getTextColour()
            term.setTextColour(colors.red)
        end
        _G.write(...)
        if term.isColour() then term.setTextColour(oldColour) end
    end,
})
local currentInput = defaultInput
local currentOutput = defaultOutput
stdin = defaultInput
stdout = defaultOutput
stderr = defaultError
function close(file)
    if file == nil then return currentOutput:close() end
    if type_of(file) ~= "table" or getmetatable(file) ~= handleMetatable then
        error("bad argument #1 (FILE expected, got " .. type_of(file) .. ")", 2)
    end
    return file:close()
end
function flush()
    return currentOutput:flush()
end
function input(file)
    if type_of(file) == "string" then
        local res, err = open(file, "r")
        if not res then error(err, 2) end
        currentInput = res
    elseif type_of(file) == "table" and getmetatable(file) == handleMetatable then
        currentInput = file
    elseif file ~= nil then
        error("bad fileument #1 (FILE expected, got " .. type_of(file) .. ")", 2)
    end
    return currentInput
end
function lines(filename, ...)
    expect(1, filename, "string", "nil")
    if filename then
        local ok, err = open(filename, "r")
        if not ok then error(err, 2) end
        ok._autoclose = true
        return ok:lines(...)
    else
        return currentInput:lines(...)
    end
end
function open(filename, mode)
    expect(1, filename, "string")
    expect(2, mode, "string", "nil")
    local sMode = mode and mode:gsub("%+", "") or "r"
    local file, err = fs.open(filename, sMode)
    if not file then return nil, err end
    return make_file(file)
end
function output(file)
    if type_of(file) == "string" then
        local res, err = open(file, "wb")
        if not res then error(err, 2) end
        currentOutput = res
    elseif type_of(file) == "table" and getmetatable(file) == handleMetatable then
        currentOutput = file
    elseif file ~= nil then
        error("bad argument #1 (FILE expected, got " .. type_of(file) .. ")", 2)
    end
    return currentOutput
end
function read(...)
    return currentInput:read(...)
end
function type(obj)
    if type_of(obj) == "table" and getmetatable(obj) == handleMetatable then
        if obj._closed then
            return "closed file"
        else
            return "file"
        end
    end
    return nil
end
function write(...)
    return currentOutput:write(...)
end