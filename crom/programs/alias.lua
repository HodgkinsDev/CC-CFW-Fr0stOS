local tArgs = { ... }
if #tArgs > 2 then
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: " .. programName .. " <alias> <program>")
    return
end
local sAlias = tArgs[1]
local sProgram = tArgs[2]
if sAlias and sProgram then
    shell.setAlias(sAlias, sProgram)
elseif sAlias then
    shell.clearAlias(sAlias)
else
    local tAliases = shell.aliases()
    local tList = {}
    for sAlias, sCommand in pairs(tAliases) do
        table.insert(tList, sAlias .. ":" .. sCommand)
    end
    table.sort(tList)
    textutils.pagedTabulate(tList)
end