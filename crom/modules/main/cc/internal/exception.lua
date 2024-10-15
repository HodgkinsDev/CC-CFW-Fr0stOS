local expect = require "cc.expect".expect
local error_printer = require "cc.internal.error_printer"
local function find_frame(thread, file, line)
    for offset = 0, 15 do
        local frame = debug.getinfo(thread, offset, "Sl")
        if not frame then break end
        if frame.short_src == file and frame.what ~= "C" and frame.currentline == line then
            return frame
        end
    end
end
local function is_exception(exn)
    if type(exn) ~= "table" then return false end
    local mt = getmetatable(exn)
    return mt and mt.__name == "exception" and type(rawget(exn, "message")) == "string" and type(rawget(exn, "thread")) == "thread"
end
local function try(func, ...)
    expect(1, func, "function")
    local co = coroutine.create(func)
    local result = table.pack(coroutine.resume(co, ...))
    while coroutine.status(co) ~= "dead" do
        local event = table.pack(os.pullEventRaw(result[2]))
        if result[2] == nil or event[1] == result[2] or event[1] == "terminate" then
            result = table.pack(coroutine.resume(co, table.unpack(event, 1, event.n)))
        end
    end
    if result[1] then
        return table.unpack(result, 1, result.n)
    elseif is_exception(result[2]) then
        local exn = result[2]
        return false, rawget(exn, "message"), rawget(exn, "thread")
    else
        return false, result[2], co
    end
end
local function report(err, thread, source_map)
    expect(2, thread, "thread")
    expect(3, source_map, "table", "nil")
    if type(err) ~= "string" then return end
    local file, line = err:match("^([^:]+):(%d+):")
    if not file then return end
    line = tonumber(line)
    local frame = find_frame(thread, file, line)
    if not frame or not frame.currentcolumn then return end
    local column = frame.currentcolumn
    local line_contents
    if source_map and source_map[frame.source] then
        local pos, contents = 1, source_map[frame.source]
        if type(contents) == "table" then
            column = column - contents.offset
            contents = contents.contents
        end
        for _ = 1, line - 1 do
            local next_pos = contents:find("\n", pos)
            if not next_pos then return end
            pos = next_pos + 1
        end
        local end_pos = contents:find("\n", pos)
        line_contents = contents:sub(pos, end_pos and end_pos - 1 or #contents)
    elseif frame.source:sub(1, 2) == "@/" then
        local handle = fs.open(frame.source:sub(3), "r")
        if not handle then return end
        for _ = 1, line - 1 do handle.readLine() end
        line_contents = handle.readLine()
    end
    if not line_contents or #line_contents == "" then return end
    error_printer({
        get_pos = function() return line, column end,
        get_line = function() return line_contents end,
    }, {
        { tag = "annotate", start_pos = column, end_pos = column, msg = "" },
    })
end
return {
    try = try,
    report = report,
}