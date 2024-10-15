local make_package = dofile("/crom/modules/main/cc/require.lua").make
local multishell = multishell
local parentShell = shell
local parentTerm = term.current()
if multishell then
    multishell.setTitle(multishell.getCurrent(), "shell")
end
local bExit = false
local sDir = parentShell and parentShell.dir() or ""
local sPath = parentShell and parentShell.path() or ".:/crom/programs"
local tAliases = parentShell and parentShell.aliases() or {}
local tCompletionInfo = parentShell and parentShell.getCompletionInfo() or {}
local tProgramStack = {}
local shell = {} 
local function createShellEnv(dir)
    local env = { shell = shell, multishell = multishell }
    env.require, env.package = make_package(env, dir)
    return env
end
local require
do
    local env = setmetatable(createShellEnv("/crom/programs"), { __index = _ENV })
    require = env.require
end
local expect = require("cc.expect").expect
local exception = require "cc.internal.exception"
local promptColour, textColour, bgColour
if term.isColour() then
    promptColour = colours.yellow
    textColour = colours.white
    bgColour = colours.black
else
    promptColour = colours.white
    textColour = colours.white
    bgColour = colours.black
end
local function tokenise(...)
    local sLine = table.concat({ ... }, " ")
    local tWords = {}
    local bQuoted = false
    for match in string.gmatch(sLine .. "\"", "(.-)\"") do
        if bQuoted then
            table.insert(tWords, match)
        else
            for m in string.gmatch(match, "[^ \t]+") do
                table.insert(tWords, m)
            end
        end
        bQuoted = not bQuoted
    end
    return tWords
end
local function executeProgram(remainingRecursion, path, args)
    local file, err = fs.open(path, "r")
    if not file then
        printError(err)
        return false
    end
    local contents = file.readLine() or ""
    if contents:sub(1, 2) == "#!" then
        file.close()
        remainingRecursion = remainingRecursion - 1
        if remainingRecursion == 0 then
            printError("Hashbang recursion depth limit reached when loading file: " .. path)
            return false
        end
        local hashbangArgs = tokenise(contents:sub(3))
        local originalHashbangPath = table.remove(hashbangArgs, 1)
        local resolvedHashbangProgram = shell.resolveProgram(originalHashbangPath)
        if not resolvedHashbangProgram then
            printError("Hashbang program not found: " .. originalHashbangPath)
            return false
        elseif resolvedHashbangProgram == "crom/programs/shell.lua" and #hashbangArgs == 0 then
            printError("Cannot use the shell as a hashbang program")
            return false
        end
        table.insert(hashbangArgs, path)
        for _, v in ipairs(args) do
            table.insert(hashbangArgs, v)
        end
        hashbangArgs[0] = originalHashbangPath
        return executeProgram(remainingRecursion, resolvedHashbangProgram, hashbangArgs)
    end
    contents = contents .. "\n" .. (file.readAll() or "")
    file.close()
    local dir = fs.getDir(path)
    local env = setmetatable(createShellEnv(dir), { __index = _G })
    env.arg = args
    local func, err = load(contents, "@/" .. path, nil, env)
    if not func then
        if #contents < 1024 * 128 then
            local parser = require "cc.internal.syntax"
            if parser.parse_program(contents) then printError(err) end
        else
            printError(err)
        end
        return false
    end
    if settings.get("bios.strict_globals", false) then
        getmetatable(env).__newindex = function(_, name)
            error("Attempt to create global " .. tostring(name), 2)
        end
    end
    local ok, err, co = exception.try(func, table.unpack(args, 1, args.n))
    if ok then return true end
    if err and err ~= "" then
        printError(err)
        exception.report(err, co)
    end
    return false
end
function shell.execute(command, ...)
    expect(1, command, "string")
    for i = 1, select('#', ...) do
        expect(i + 1, select(i, ...), "string")
    end
    local sPath = shell.resolveProgram(command)
    if sPath ~= nil then
        tProgramStack[#tProgramStack + 1] = sPath
        if multishell then
            local sTitle = fs.getName(sPath)
            if sTitle:sub(-4) == ".lua" then
                sTitle = sTitle:sub(1, -5)
            end
            multishell.setTitle(multishell.getCurrent(), sTitle)
        end
        local result = executeProgram(100, sPath, { [0] = command, ... })
        tProgramStack[#tProgramStack] = nil
        if multishell then
            if #tProgramStack > 0 then
                local sTitle = fs.getName(tProgramStack[#tProgramStack])
                if sTitle:sub(-4) == ".lua" then
                    sTitle = sTitle:sub(1, -5)
                end
                multishell.setTitle(multishell.getCurrent(), sTitle)
            else
                multishell.setTitle(multishell.getCurrent(), "shell")
            end
        end
        return result
       else
        printError("No such program")
        return false
    end
end
function shell.run(...)
    local tWords = tokenise(...)
    local numWords = #tWords
    local sCommand = tWords[1]

    if numWords == 1 and sCommand:sub(-4) == ".bf" then
        return shell.execute("bf.lua", sCommand)
    elseif numWords == 1 and sCommand:sub(-4) == ".fsc" then
        -- Check if the path contains a '/', and if not, prepend the current directory
        if not string.find(sCommand, "/") then
            local currentDir = shell.dir()
            sCommand = fs.combine(currentDir, sCommand)
        end
        -- Call fkernel.fileShortcut with the modified path
        return fkernel.fileShortcut(sCommand)
    elseif sCommand then
        return shell.execute(sCommand, table.unpack(tWords, 2))
    end

    return false
end
function shell.exit()
    bExit = true
end
function shell.dir()
    return sDir
end
function shell.setDir(dir)
    expect(1, dir, "string")
    if not fs.isDir(dir) then
        error("Not a directory", 2)
    end
    sDir = fs.combine(dir, "")
end 
function shell.path()
    return sPath
end
function shell.setPath(path)
    expect(1, path, "string")
    sPath = path
end
function shell.reset_term()
    shell.run("clear")
    
    if term.isColour() then
        promptColour = colours.yellow
        textColour = colours.yellow
        bgColour = colours.black
        term.setTextColor(textColour) -- Set text color to yellow
    end

    print(os.version()) -- Now this will print in yellow if in color mode

    if term.isColour() then
        promptColour = colours.yellow
        textColour = colours.white
        bgColour = colours.black
        term.setTextColor(textColour) -- Set text color to white for the next prints
    end

    shell.run("motd")
end
function shell.resolve(path)
    expect(1, path, "string")
    local sStartChar = string.sub(path, 1, 1)
    if sStartChar == "/" or sStartChar == "\\" then
        return fs.combine("", path)
    else
        return fs.combine(sDir, path)
    end
end
local function pathWithExtension(_sPath, _sExt)
    local nLen = #sPath
    local sEndChar = string.sub(_sPath, nLen, nLen)
    if sEndChar == "/" or sEndChar == "\\" then
        _sPath = string.sub(_sPath, 1, nLen - 1)
    end
    return _sPath .. "." .. _sExt
end
function shell.resolveProgram(command)
    expect(1, command, "string")
    if tAliases[command] ~= nil then
        command = tAliases[command]
    end
    if command:find("/") or command:find("\\") then
        local sPath = shell.resolve(command)
        if fs.exists(sPath) and not fs.isDir(sPath) then
            return sPath
        else
            local sPathLua = pathWithExtension(sPath, "lua")
            if fs.exists(sPathLua) and not fs.isDir(sPathLua) then
                return sPathLua
            end
        end
        return nil
    end
    for sPath in string.gmatch(sPath, "[^:]+") do
        sPath = fs.combine(shell.resolve(sPath), command)
        if fs.exists(sPath) and not fs.isDir(sPath) then
            return sPath
        else
            local sPathLua = pathWithExtension(sPath, "lua")
            if fs.exists(sPathLua) and not fs.isDir(sPathLua) then
                return sPathLua
            end
        end
    end
    return nil
end
function shell.programs(include_hidden)
    expect(1, include_hidden, "boolean", "nil")
    local tItems = {}
    for sPath in string.gmatch(sPath, "[^:]+") do
        sPath = shell.resolve(sPath)
        if fs.isDir(sPath) then
            local tList = fs.list(sPath)
            for n = 1, #tList do
                local sFile = tList[n]
                if not fs.isDir(fs.combine(sPath, sFile)) and
                   (include_hidden or string.sub(sFile, 1, 1) ~= ".") then
                    if #sFile > 4 and sFile:sub(-4) == ".lua" then
                        sFile = sFile:sub(1, -5)
                    end
                    tItems[sFile] = true
                end
            end
        end
    end
    local tItemList = {}
    for sItem in pairs(tItems) do
        table.insert(tItemList, sItem)
    end
    table.sort(tItemList)
    return tItemList
end
local function completeProgram(sLine)
    local bIncludeHidden = settings.get("shell.autocomplete_hidden")
    if #sLine > 0 and (sLine:find("/") or sLine:find("\\")) then
        return fs.complete(sLine, sDir, {
            include_files = true,
            include_dirs = false,
            include_hidden = bIncludeHidden,
        })
    else
        local tResults = {}
        local tSeen = {}
        for sAlias in pairs(tAliases) do
            if #sAlias > #sLine and string.sub(sAlias, 1, #sLine) == sLine then
                local sResult = string.sub(sAlias, #sLine + 1)
                if not tSeen[sResult] then
                    table.insert(tResults, sResult)
                    tSeen[sResult] = true
                end
            end
        end
        local tDirs = fs.complete(sLine, sDir, {
            include_files = false,
            include_dirs = false,
            include_hidden = bIncludeHidden,
        })
        for i = 1, #tDirs do
            local sResult = tDirs[i]
            if not tSeen[sResult] then
                table.insert (tResults, sResult)
                tSeen [sResult] = true
            end
        end
        local tPrograms = shell.programs()
        for n = 1, #tPrograms do
            local sProgram = tPrograms[n]
            if #sProgram > #sLine and string.sub(sProgram, 1, #sLine) == sLine then
                local sResult = string.sub(sProgram, #sLine + 1)
                if not tSeen[sResult] then
                    table.insert(tResults, sResult)
                    tSeen[sResult] = true
                end
            end
        end
        table.sort(tResults)
        return tResults
    end
end
local function completeProgramArgument(sProgram, nArgument, sPart, tPreviousParts)
    local tInfo = tCompletionInfo[sProgram]
    if tInfo then
        return tInfo.fnComplete(shell, nArgument, sPart, tPreviousParts)
    end
    return nil
end
function shell.complete(sLine)
    expect(1, sLine, "string")
    if #sLine > 0 then
        local tWords = tokenise(sLine)
        local nIndex = #tWords
        if string.sub(sLine, #sLine, #sLine) == " " then
            nIndex = nIndex + 1
        end
        if nIndex == 1 then
            local sBit = tWords[1] or ""
            local sPath = shell.resolveProgram(sBit)
            if tCompletionInfo[sPath] then
                return { " " }
            else
                local tResults = completeProgram(sBit)
                for n = 1, #tResults do
                    local sResult = tResults[n]
                    local sPath = shell.resolveProgram(sBit .. sResult)
                    if tCompletionInfo[sPath] then
                        tResults[n] = sResult .. " "
                    end
                end
                return tResults
            end
        elseif nIndex > 1 then
            local sPath = shell.resolveProgram(tWords[1])
            local sPart = tWords[nIndex] or ""
            local tPreviousParts = tWords
            tPreviousParts[nIndex] = nil
            return completeProgramArgument(sPath , nIndex - 1, sPart, tPreviousParts)
        end
    end
    return nil
end
function shell.completeProgram(program)
    expect(1, program, "string")
    return completeProgram(program)
end
function shell.setCompletionFunction(program, complete)
    expect(1, program, "string")
    expect(2, complete, "function")
    tCompletionInfo[program] = {
        fnComplete = complete,
    }
end
function shell.getCompletionInfo()
    return tCompletionInfo
end
function shell.getRunningProgram()
    if #tProgramStack > 0 then
        return tProgramStack[#tProgramStack]
    end
    return nil
end
function shell.setAlias(command, program)
    expect(1, command, "string")
    expect(2, program, "string")
    tAliases[command] = program
end
function shell.clearAlias(command)
    expect(1, command, "string")
    tAliases[command] = nil
end
function shell.aliases()
    local tCopy = {}
    for sAlias, sCommand in pairs(tAliases) do
        tCopy[sAlias] = sCommand
    end
    return tCopy
end
if multishell then
    function shell.openTab(...)
        local tWords = tokenise(...)
        local sCommand = tWords[1]
        if sCommand then
            local sPath = shell.resolveProgram(sCommand)
            if sPath == "crom/programs/shell.lua" then
                return multishell.launch(createShellEnv("crom/programs"), sPath, table.unpack(tWords, 2))
            elseif sPath ~= nil then
                return multishell.launch(createShellEnv("crom/programs"), "crom/programs/shell.lua", sCommand, table.unpack(tWords, 2))
            else
                printError("No such program")
            end
        end
    end
    function shell.switchTab(id)
        expect(1, id, "number")
        multishell.setFocus(id)
    end
end
local tArgs = { ... }
if #tArgs > 0 then
    shell.run(...)
else
    local function show_prompt()
        term.setBackgroundColor(bgColour)
        term.setTextColour(promptColour)
        write(shell.dir() .. "> ")
        term.setTextColour(textColour)
    end
    term.setBackgroundColor(bgColour)
    term.setTextColour(promptColour)
    print(os.version())
    term.setTextColour(textColour)
    if parentShell == nil then
        shell.run("crom/startup.lua")
    end
	shell.run("cd crom/")
	shell.run("cd usr/")
	shell.run("cd " ..fkernel.getUsername())
	shell.run("cd home/")
    local tCommandHistory = {}
    while not bExit do
        term.redirect(parentTerm)
        show_prompt()
        local complete
        if settings.get("shell.autocomplete") then complete = shell.complete end
        local ok, result
        local co = coroutine.create(read)
        assert(coroutine.resume(co, nil, tCommandHistory, complete))
        while coroutine.status(co) ~= "dead" do
            local event = table.pack(os.pullEvent())
            if event[1] == "file_transfer" then
                local _, h = term.getSize()
                local _, y = term.getCursorPos()
                if y == h then
                    term.scroll(1)
                    term.setCursorPos(1, y)
                else
                    term.setCursorPos(1, y + 1)
                end
                term.setCursorBlink(false)
                local ok, err = require("cc.internal.import")(event[2].getFiles())
                if not ok and err then printError(err) end
                show_prompt()
                term.setCursorBlink(true)
                event = { "term_resize", n = 1 } 
            end
            if result == nil or event[1] == result or event[1] == "terminate" then
                ok, result = coroutine.resume(co, table.unpack(event, 1, event.n))
                if not ok then error(result, 0) end
            end
        end
        if result:match("%S") and tCommandHistory[#tCommandHistory] ~= result then
            table.insert(tCommandHistory, result)
        end
        shell.run(result)
    end
end