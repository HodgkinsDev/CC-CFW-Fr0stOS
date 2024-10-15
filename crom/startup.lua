local completion = require "cc.shell.completion"
local sPath = ".:/crom/programs:/crom/programs/http"
sPath = sPath .. ":/crom/programs/advanced"
sPath = sPath .. ":/crom/programs/turtle"
sPath = sPath .. ":/crom/programs/rednet:/crom/programs/fun"
sPath = sPath .. ":/crom/programs/fun/advanced"
sPath = sPath .. ":/crom/programs/pocket"
sPath = sPath .. ":/crom/programs/command"
shell.setPath(sPath)
help.setPath("/crom/help")
shell.setAlias("ls", "list")
shell.setAlias("dir", "list")
shell.setAlias("cp", "copy")
shell.setAlias("mv", "move")
shell.setAlias("rm", "delete")
shell.setAlias("clr", "clear")
shell.setAlias("rs", "redstone")
shell.setAlias("sh", "shell")
shell.setAlias("background", "bg")
shell.setAlias("foreground", "fg")
local function completePastebinPut(shell, text, previous)
    if previous[2] == "put" then
        return fs.complete(text, shell.dir(), true, false)
    end
end
shell.setCompletionFunction("crom/programs/alias.lua", completion.build(nil, completion.program))
shell.setCompletionFunction("crom/programs/cd.lua", completion.build(completion.dir))
shell.setCompletionFunction("crom/programs/clear.lua", completion.build({ completion.choice, { "screen", "palette", "all" } }))
shell.setCompletionFunction("crom/programs/copy.lua", completion.build(
    { completion.dirOrFile, true },
    completion.dirOrFile
))
shell.setCompletionFunction("crom/programs/delete.lua", completion.build({ completion.dirOrFile, many = true }))
shell.setCompletionFunction("crom/programs/drive.lua", completion.build(completion.dir))
shell.setCompletionFunction("crom/programs/edit.lua", completion.build(completion.file))
shell.setCompletionFunction("crom/programs/eject.lua", completion.build(completion.peripheral))
shell.setCompletionFunction("crom/programs/gps.lua", completion.build({ completion.choice, { "host", "host ", "locate" } }))
shell.setCompletionFunction("crom/programs/help.lua", completion.build(completion.help))
shell.setCompletionFunction("crom/programs/id.lua", completion.build(completion.peripheral))
shell.setCompletionFunction("crom/programs/label.lua", completion.build(
    { completion.choice, { "get", "get ", "set ", "clear", "clear " } },
    completion.peripheral
))
shell.setCompletionFunction("crom/programs/list.lua", completion.build(completion.dir))
shell.setCompletionFunction("crom/programs/mkdir.lua", completion.build({ completion.dir, many = true }))
local complete_monitor_extra = { "scale" }
shell.setCompletionFunction("crom/programs/monitor.lua", completion.build(
    function(shell, text, previous)
        local choices = completion.peripheral(shell, text, previous, true)
        for _, option in pairs(completion.choice(shell, text, previous, complete_monitor_extra, true)) do
            choices[#choices + 1] = option
        end
        return choices
    end,
    function(shell, text, previous)
        if previous[2] == "scale" then
            return completion.peripheral(shell, text, previous, true)
        else
            return completion.programWithArgs(shell, text, previous, 3)
        end
    end,
    {
        function(shell, text, previous)
            if previous[2] ~= "scale" then
                return completion.programWithArgs(shell, text, previous, 3)
            end
        end,
        many = true,
    }
))
shell.setCompletionFunction("crom/programs/move.lua", completion.build(
    { completion.dirOrFile, true },
    completion.dirOrFile
))
shell.setCompletionFunction("crom/programs/redstone.lua", completion.build(
    { completion.choice, { "probe", "set ", "pulse " } },
    completion.side
))
shell.setCompletionFunction("crom/programs/rename.lua", completion.build(
    { completion.dirOrFile, true },
    completion.dirOrFile
))
shell.setCompletionFunction("crom/programs/shell.lua", completion.build({ completion.programWithArgs, 2, many = true }))
shell.setCompletionFunction("crom/programs/type.lua", completion.build(completion.dirOrFile))
shell.setCompletionFunction("crom/programs/set.lua", completion.build({ completion.setting, true }))
shell.setCompletionFunction("crom/programs/advanced/bg.lua", completion.build({ completion.programWithArgs, 2, many = true }))
shell.setCompletionFunction("crom/programs/advanced/fg.lua", completion.build({ completion.programWithArgs, 2, many = true }))
shell.setCompletionFunction("crom/programs/fun/dj.lua", completion.build(
    { completion.choice, { "play", "play ", "stop " } },
    completion.peripheral
))
shell.setCompletionFunction("crom/programs/fun/speaker.lua", completion.build(
    { completion.choice, { "play ", "sound ", "stop " } },
    function(shell, text, previous)
        if previous[2] == "play" then return completion.file(shell, text, previous, true)
        elseif previous[2] == "stop" then return completion.peripheral(shell, text, previous, false)
        end
    end,
    function(shell, text, previous)
        if previous[2] == "play" then return completion.peripheral(shell, text, previous, false)
        end
    end
))
shell.setCompletionFunction("crom/programs/fun/advanced/paint.lua", completion.build(completion.file))
shell.setCompletionFunction("crom/programs/http/pastebin.lua", completion.build(
    { completion.choice, { "put ", "get ", "run " } },
    completePastebinPut
))
shell.setCompletionFunction("crom/programs/rednet/chat.lua", completion.build({ completion.choice, { "host ", "join " } }))
shell.setCompletionFunction("crom/programs/command/exec.lua", completion.build(completion.command))
shell.setCompletionFunction("crom/programs/http/wget.lua", completion.build({ completion.choice, { "run " } }))
if turtle then
    shell.setCompletionFunction("crom/programs/turtle/go.lua", completion.build(
        { completion.choice, { "left", "right", "forward", "back", "down", "up" }, true, many = true }
    ))
    shell.setCompletionFunction("crom/programs/turtle/turn.lua", completion.build(
        { completion.choice, { "left", "right" }, true, many = true }
    ))
    shell.setCompletionFunction("crom/programs/turtle/equip.lua", completion.build(
        nil,
        { completion.choice, { "left", "right" } }
    ))
    shell.setCompletionFunction("crom/programs/turtle/unequip.lua", completion.build(
        { completion.choice, { "left", "right" } }
    ))
end
if fs.exists("/crom/autorun") and fs.isDir("/crom/autorun") then
    local tFiles = fs.list("/crom/autorun")
    for _, sFile in ipairs(tFiles) do
        if string.sub(sFile, 1, 1) ~= "." then
            local sPath = "/crom/autorun/" .. sFile
            if not fs.isDir(sPath) then
                shell.run(sPath)
            end
        end
    end
end
local function findStartups(sBaseDir)
    local tStartups = nil
    local sBasePath = "/" .. fs.combine(sBaseDir, "startup")
    local sStartupNode = shell.resolveProgram(sBasePath)
    if sStartupNode then
        tStartups = { sStartupNode }
    end
    if fs.isDir(sBasePath) then
        if tStartups == nil then
            tStartups = {}
        end
        for _, v in pairs(fs.list(sBasePath)) do
            local sPath = "/" .. fs.combine(sBasePath, v)
            if not fs.isDir(sPath) then
                tStartups[#tStartups + 1] = sPath
            end
        end
    end
    return tStartups
end
if settings.get("motd.enable") then
    shell.run("motd")
end
local function checkUpdateFile()
    if fs.exists("/boot/update.lua") then
        return 0 -- File exists
    else
        return 1 -- File does not exist
    end
end
local function checkfkernelFile()
    if fs.exists("/boot/fkernel.lua") then
        return 0 -- File exists
    else
        return 1 -- File does not exist
    end
end
if checkUpdateFile() == 0 then
    shell.run("/boot/update.lua")
else
    shell.run("clear")
    printError("Fr0stOS:/boot/update.lua was not found. Can't Boot")
    print("Press any key to enter...")
    os.pullEvent("key") -- Waits for any key to be pressed
    os.reboot() -- Reboots the system
end
if checkfkernelFile() == 0 then
	shell.run("/boot/fkernel.lua")
else
	shell.run("clear")
    printError("Fr0stOS:/boot/fkernel.lua was not found. Can't Boot")
    print("Press any key to enter...")
    os.pullEvent("key") -- Waits for any key to be pressed
    os.reboot() -- Reboots the system
end
if fkernel.getUsername() == "N/A" then
	shell.run("clear")
    printError("Fr0stOS:Unexpected Error logging in. Can't Boot")
    print("Press any key to enter...")
    os.pullEvent("key") -- Waits for any key to be pressed
    os.reboot() -- Reboots the system
end
local tUserStartups = nil
if settings.get("shell.allow_startup") then
    tUserStartups = findStartups("/")
end
if settings.get("shell.allow_disk_startup") then
    for _, sName in pairs(peripheral.getNames()) do
        if disk.isPresent(sName) and disk.hasData(sName) then
            local startups = findStartups(disk.getMountPath(sName))
            if startups then
                tUserStartups = startups
                break
            end
        end
    end
end
if tUserStartups then
    for _, v in pairs(tUserStartups) do
        shell.run(v)
    end
end
