local tArgs = { ... }
local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " play")
    print(programName .. " play <drive>")
    print(programName .. " stop")
end
if #tArgs > 2 then
    printUsage()
    return
end
local sCommand = tArgs[1]
if sCommand == "stop" then
    disk.stopAudio()
elseif sCommand == "play" or sCommand == nil then
    local sName = tArgs[2]
    if sName == nil then
        local tNames = {}
        for _, sName in ipairs(peripheral.getNames()) do
            if disk.isPresent(sName) and disk.hasAudio(sName) then
                table.insert(tNames, sName)
            end
        end
        if #tNames == 0 then
            print("No Music Discs in attached disk drives")
            return
        end
        sName = tNames[math.random(1, #tNames)]
    end
    if disk.isPresent(sName) and disk.hasAudio(sName) then
        print("Playing " .. disk.getAudioTitle(sName))
        disk.playAudio(sName)
    else
        print("No Music Disc in disk drive: " .. sName)
        return
    end
else
    printUsage()
end