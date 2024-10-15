local tArgs = { ... }

-- Check if at least one argument is provided
if #tArgs < 1 then
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage: " .. programName .. " <path>")
    return
end

local sNewDir = shell.resolve(tArgs[1])

-- Check if the path is a file that ends with .stc
if not fs.isDir(sNewDir) and string.match(sNewDir, "%.dsc$") then
    -- Call fkernel.shortcutDIR with the path
    fkernel.dirShortcut(sNewDir)
    return
end

-- If the path is a directory, change to it
if fs.isDir(sNewDir) then
    shell.setDir(sNewDir)
else
    -- Otherwise, print an error if the path is not a directory
    print("Not a directory")
    return
end
