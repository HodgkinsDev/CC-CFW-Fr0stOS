local SYSRAN = false
local readOnlyPaths = {}
function fs.setReadOnlyFile(path, readOnly)
    if SYSRAN == false then
		local SystemRan = fkernel.SysCall()
	elseif SYSRAN == true then
		local SystemRan = true
	end
    if fkernel.getPermissions() == "User" and readOnly == false and SystemRan == false then
        print("Only Admins can disable readOnly") 
        return
    else
        if type(path) == "string" and type(readOnly) == "boolean" then
            if readOnly then
                table.insert(readOnlyPaths, path)
            else
                for i, readOnlyPath in ipairs(readOnlyPaths) do
                    if readOnlyPath == path then
                        table.remove(readOnlyPaths, i)
                        break
                    end
                end
            end
        else
            print("Invalid arguments for fs.setReadOnlyFile") 
        end
    end
end
function fkernel.dirShortcut(filePath)
    -- Check if the file has the .stc extension
    if not string.match(filePath, "%.dsc$") then
        return 1  -- Return 1 if the file doesn't have a .stc extension
    end

    -- Open the file for reading
    local file = fs.open(filePath, "r")
    if not file then
        return 2  -- Return 2 if the file could not be opened
    end

    -- Read the first line of the file, which should contain the path
    local targetPath = file.readLine()
    file.close()

    -- If no path is found, return error
    if not targetPath or targetPath == "" then
        return 3  -- Return 3 if no path is found in the file
    end

    -- Attempt to change to the directory using the path from the file
    local success, err = shell.run("cd " .. targetPath)

    -- Return 4 if changing directory fails
    if not success then
        return 4
    end

    -- Return 0 for success
    return 0
end

function fkernel.fileShortcut(filePath)
    -- Check if the file has the .fsc extension
    if not string.match(filePath, "%.fsc$") then
        return 1  -- Return 1 if the file doesn't have a .fsc extension
    end

    -- Open the file for reading
    local file = fs.open(filePath, "r")
    if not file then
        return 2  -- Return 2 if the file could not be opened
    end

    -- Read the first line of the file, which should contain the command to run
    local commandToRun = file.readLine()
    file.close()

    -- If no command is found, return error
    if not commandToRun or commandToRun == "" then
        return 3  -- Return 3 if no command is found in the file
    end

    -- Attempt to run the command from the file
    local success, err = shell.run(commandToRun)

    -- Return 4 if running the command fails
    if not success then
        return 4
    end

    -- Return 0 for success
    return 0
end


local function normalizePath(path)
    path = path:gsub("%.%.", "")
    path = path:gsub("[\\/]([\\/]+)", "/")
    path = path:gsub("[\\/]$", "")
    return path
end
local function isReadOnly(path)
    path = normalizePath(path)
    for _, readOnlyPath in ipairs(readOnlyPaths) do
        if path:sub(1, #normalizePath(readOnlyPath)) == normalizePath(readOnlyPath) then
            return true
        end
    end
    return false
end
local old_fsOpen = _G["fs"]["open"]
local old_fsIsReadOnly = _G["fs"]["isReadOnly"]
local old_fsDelete = _G["fs"]["delete"]
local old_fsMove = _G["fs"]["move"]
local old_fsCopy = _G["fs"]["copy"]
local old_fsWrite = _G["fs"]["write"]
local old_fsAppend = _G["fs"]["append"]
local old_fsMakeDir = _G["fs"]["makeDir"]
local old_fsDeleteDir = _G["fs"]["deleteDir"]
_G["fs"]["open"] = function(path, mode)
    path = normalizePath(path)
    if isReadOnly(path) and (mode == 'w' or mode == 'd') then
        return nil
    else
        return old_fsOpen(path, mode)
    end
end
_G["fs"]["isReadOnly"] = function(path)
    path = normalizePath(path)
    if isReadOnly(path) then
        return true
    else
        return old_fsIsReadOnly(path)
    end
end
_G["fs"]["delete"] = function(path)
    path = normalizePath(path)
    if isReadOnly(path) then
        return nil
    else
        return old_fsDelete(path)
    end
end
_G["fs"]["move"] = function(fromPath, toPath)
    local userPermissions = fkernel.getPermissions()  -- Retrieve user permissions
    local username = fkernel.getUsername()            -- Get the current username

    fromPath = normalizePath(fromPath)
    toPath = normalizePath(toPath)

    -- Define the expected home directory paths
    local expectedPath1 = "crom/usr/" .. username .. "/home"
    local expectedPath2 = "/crom/usr/" .. username .. "/home"
    local expectedDiskPath = "disk/"  -- Add '/disk' as a valid path

    -- Check if the user is a 'User' and validate the 'toPath'
    if userPermissions == "User" and
       not (toPath:sub(1, #expectedPath1) == expectedPath1 or 
            toPath:sub(1, #expectedPath2) == expectedPath2 or 
            toPath:sub(1, #expectedDiskPath) == expectedDiskPath) then
        term.setTextColor(colors.red)
        print("Permission Denied: Can't move file here!")
        term.setTextColor(colors.white)
        return nil  -- Deny if destination is outside the user's allowed directory
    end

    -- Check if either 'fromPath' or 'toPath' is read-only
    if isReadOnly(fromPath) or isReadOnly(toPath) then
        return nil
    else
        return old_fsMove(fromPath, toPath)
    end
end

_G["fs"]["copy"] = function(fromPath, toPath)
    local userPermissions = fkernel.getPermissions()  -- Retrieve user permissions
    local username = fkernel.getUsername()            -- Get the current username
    
    fromPath = normalizePath(fromPath)
    toPath = normalizePath(toPath)

    -- Define the expected home directory paths
    local expectedPath1 = "crom/usr/" .. username .. "/home"
    local expectedPath2 = "/crom/usr/" .. username .. "/home"
    local expectedDiskPath = "disk/"  -- Add '/disk' as a valid path

    -- Check if the user is a 'User' and validate the 'toPath'
    if userPermissions == "User" and 
       not (toPath:sub(1, #expectedPath1) == expectedPath1 or 
            toPath:sub(1, #expectedPath2) == expectedPath2 or 
            toPath:sub(1, #expectedDiskPath) == expectedDiskPath) then
        term.setTextColor(colors.red)
        print("Permission Denied: Can't copy file here!")
        term.setTextColor(colors.white)
        return nil  -- Deny if destination is outside the user's allowed directory
    end

    -- Check if either 'fromPath' or 'toPath' is read-only
    if isReadOnly(fromPath) or isReadOnly(toPath) then
        return nil
    else
        return old_fsCopy(fromPath, toPath)
    end
end


_G["fs"]["write"] = function(path, text)
    path = normalizePath(path)
    if isReadOnly(path) then
        return nil
    else
        return old_fsWrite(path, text)
    end
end
_G["fs"]["append"] = function(path, text)
    path = normalizePath(path)
    if isReadOnly(path) then
        return nil
    else
        return old_fsAppend(path, text)
    end
end
_G["fs"]["makeDir"] = function(path)
    path = normalizePath(path)
    if isReadOnly(path) then
        return nil
    else
        return old_fsMakeDir(path)
    end
end
_G["fs"]["deleteDir"] = function(path)
    path = normalizePath(path)
    if isReadOnly(path) then
        return nil
    else
        return old_fsDeleteDir(path)
    end
end
function fs.setReadOnlyForAllFiles(path, readOnly)
	SystemRan = fkernel.SysCall()
	if fkernel.getPermissions() == "User" and readOnly == false and SystemRan == false then
		print("Only Admins can disable readOnly")
		return
	else 
		local function setReadOnlyRecursive(currentPath)
			local items = fs.list(currentPath)
			for _, item in ipairs(items) do
				local fullPath = fs.combine(currentPath, item)
				if fs.isDir(fullPath) then
					fs.setReadOnlyFile(fullPath, readOnly)  
					setReadOnlyRecursive(fullPath)      
				else
					fs.setReadOnlyFile(fullPath, readOnly)
				end
			end
		end
		setReadOnlyRecursive(path)
	end
end
local function setFSPermissions(path,ReadOnly)
	SYSRAN = true
	local homeDir = "crom/usr/" .. fkernel.getUsername() .. "/home"
	local function setPermissionsRecursive(currentPath)
		local items = fs.list(currentPath)
		for _, item in ipairs(items) do
			local fullPath = fs.combine(currentPath, item)
			if not string.find(fullPath, homeDir, 1, ReadOnly) then
				if fs.isDir(fullPath) then
					setPermissionsRecursive(fullPath)
				else
					fs.setReadOnlyFile(fullPath, ReadOnly)
				end
			end
		end
	end
	setPermissionsRecursive(path)
	SYSRAN = false
end
function fs.setSystemReadOnly(ReadOnly)
	setFSPermissions("/",ReadOnly)
end
fkernel.init()
local function checkLoginFile()
    if fs.exists("/boot/login.lua") then
        return 0 -- File exists
    else
        return 1 -- File does not exist
    end
end
if checkLoginFile() == 0 then
	shell.run("/boot/login.lua")
else
	shell.run("clear")
    printError("Fr0stOS:/boot/login.lua was not found. Can't Boot")
    print("Press any key to enter...")
    os.pullEvent("key") -- Waits for any key to be pressed
    os.reboot() -- Reboots the system
end
