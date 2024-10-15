local expect = require "cc.expect".expect
local completion = require "cc.completion"
local function file(shell, text)
    return fs.complete(text, shell.dir(), {
        include_files = true,
        include_dirs = false,
        include_hidden = settings.get("shell.autocomplete_hidden"),
    })
end
local function dir(shell, text)
    return fs.complete(text, shell.dir(), {
        include_files = false,
        include_dirs = true,
        include_hidden = settings.get("shell.autocomplete_hidden"),
    })
end
local function dirOrFile(shell, text, previous, add_space)
    local results = fs.complete(text, shell.dir(), {
        include_files = true,
        include_dirs = true,
        include_hidden = settings.get("shell.autocomplete_hidden"),
    })
    if add_space then
        for n = 1, #results do
            local result = results[n]
            if result:sub(-1) ~= "/" then
                results[n] = result .. " "
            end
        end
    end
    return results
end
local function wrap(func)
    return function(shell, text, previous, ...)
        return func(text, ...)
    end
end
local function program(shell, text)
    return shell.completeProgram(text)
end
local function programWithArgs(shell, text, previous, starting)
    if #previous + 1 == starting then
        local tCompletionInfo = shell.getCompletionInfo()
        if text:sub(-1) ~= "/" and tCompletionInfo[shell.resolveProgram(text)] then
            return { " " }
        else
            local results = shell.completeProgram(text)
            for n = 1, #results do
                local sResult = results[n]
                if sResult:sub(-1) ~= "/" and tCompletionInfo[shell.resolveProgram(text .. sResult)] then
                    results[n] = sResult .. " "
                end
            end
            return results
        end
    else
        local program = previous[starting]
        local resolved = shell.resolveProgram(program)
        if not resolved then return end
        local tCompletion = shell.getCompletionInfo()[resolved]
        if not tCompletion then return end
        return tCompletion.fnComplete(shell, #previous - starting + 1, text, { program, table.unpack(previous, starting + 1, #previous) })
    end
end
local function build(...)
    local arguments = table.pack(...)
    for i = 1, arguments.n do
        local arg = arguments[i]
        if arg ~= nil then
            expect(i, arg, "table", "function")
            if type(arg) == "function" then
                arg = { arg }
                arguments[i] = arg
            end
            if type(arg[1]) ~= "function" then
                error(("Bad table entry #1 at argument #%d (function expected, got %s)"):format(i, type(arg[1])), 2)
            end
            if arg.many and i < arguments.n then
                error(("Unexpected 'many' field on argument #%d (should only occur on the last argument)"):format(i), 2)
            end
        end
    end
    return function(shell, index, text, previous)
        local arg = arguments[index]
        if not arg then
            if index <= arguments.n then return end
            arg = arguments[arguments.n]
            if not arg or not arg.many then return end
        end
        return arg[1](shell, text, previous, table.unpack(arg, 2))
    end
end
return {
    file = file,
    dir = dir,
    dirOrFile = dirOrFile,
    program = program,
    programWithArgs = programWithArgs,
    help = wrap(help.completeTopic), 
    choice = wrap(completion.choice), 
    peripheral = wrap(completion.peripheral), 
    side = wrap(completion.side), 
    setting = wrap(completion.setting), 
    command = wrap(completion.command), 
    build = build,
}