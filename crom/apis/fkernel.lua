local OS_VER = "0.1.1"
local expect
fkernel = {}
local Global_VAR
local expect = dofile("crom/modules/main/cc/expect.lua").expect
function getVersion()
	return OS_VER
end
function GlobalVAR(str)
	Global_VAR = str
end
function getGlobalVAR()
	return Global_VAR
end

function findModemFace()
  local modemSides = { "top", "bottom", "front", "back", "left", "right" }
  for _, side in pairs(modemSides) do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
      return side
    end
  end
  return nil
end
local function turnOnRedNet(side)
  if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
    rednet.open(side) 
    return true 
  else
    return false 
  end
end
function enableModem()
	turnOnRedNet(findModemFace())
end
local function turnOffRedNet(side)
  if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
    rednet.close(side) 
    return true 
  else
    return false 
  end
end
function disableModem()
	turnOffRedNet(findModemFace())
end
local Account_Username = "N/A"
local Account_Password
local Account_Permission = "User"
local userlist
local passlist
local permlist
local SystemRan = false
local function EncryptPassword(str)
    local hexStr = ""

    -- Function to rotate bits in a byte to the left by a given number of positions
    local function rotateLeft(byteValue, positions)
        -- Shift left and then mask out any bits that went past 8 bits
        local shifted = bit32.band(bit32.lshift(byteValue, positions), 0xFF)
        -- Bring the bits that were shifted out back in on the right
        local rotated = bit32.bor(shifted, bit32.rshift(byteValue, 8 - positions))
        return rotated
    end

    for i = 1, #str do
        local byteValue = string.byte(str, i)  -- Get the ASCII value of the character
        byteValue = (byteValue + 2) % 256      -- Add 2 and use modulo to handle rollover beyond 255
        byteValue = rotateLeft(byteValue, 2)   -- Perform the bitwise circular shift by 2 positions
        local hex = string.format("%02X", byteValue)  -- Convert to hex format
        hexStr = hexStr .. hex                 -- Concatenate the hex value to the final string
    end
    return hexStr
end
local function DecryptPassword(hexStr)
    -- Function to shift bits right and roll over
    local function rotateRight(value, positions)
        positions = positions % 8  -- Ensure we are shifting within byte range
        local lowerBits = bit32.extract(value, 0, positions)
        local shifted = bit32.rshift(value, positions)
        return bit32.bor(bit32.lshift(lowerBits, 8 - positions), shifted)
    end

    local str = ""
    for i = 1, #hexStr, 2 do
        local hexByte = hexStr:sub(i, i + 1)  -- Extract each two-character hex byte
        local byteValue = tonumber(hexByte, 16)  -- Convert hex to number

        -- Rotate right by 2 positions
        byteValue = rotateRight(byteValue, 2)

        -- Subtract 2, with rollover to 255 if less than 2
        if byteValue < 2 then
            byteValue = 255 + (byteValue - 1)  -- Roll over underflow handling
        else
            byteValue = byteValue - 2
        end

        -- Convert to character and add to string
        str = str .. string.char(byteValue)
    end
    return str
end
function getUsername()
	return Account_Username
end
function getUserList()
	return userlist
end
function getPermissions()
	return Account_Permission
end
function getHomeDir()
    local usrnme = getUsername()
    return "/crom/usr/" .. usrnme .. "/home/"
end
local function parseUserFile(filename)
    local file = io.open(filename, "r")
    local content = file:read("*a")
    file:close()
    local usernames = {}
    local passwords = {}
    local perms = {}
    for account in content:gmatch("<Account>(.-)</Account>") do
        local username = account:match("<Username>(.-)</Username>")
        local password = account:match("<Password>(.-)</Password>") or ""
        local perm = account:match("<Perm>(.-)</Perm>") or ""
        if username then
            table.insert(usernames, username)
            table.insert(passwords, password)
            table.insert(perms, perm)
        end
    end
    return usernames, passwords, perms
end
function init()
    local baseDir = "crom"
    local usrDir = baseDir .. "/usr"
    local defaultDir = usrDir .. "/Default"
    local homeDir = defaultDir .. "/home"
    local guestDir = usrDir .. "/Guest"
    local guestHomeDir = guestDir .. "/home"

    local function createDir(path)
        if not fs.exists(path) then
            fs.makeDir(path)
        end
    end
	createDir(baseDir)
    createDir(usrDir)
    createDir(defaultDir)
    createDir(homeDir)
    createDir(guestDir)
    createDir(guestHomeDir)

    if not fs.exists("/crom/usr/acc.xml") then
        local pass = EncryptPassword("1234") -- Get the encrypted password
        local file = fs.open("/crom/usr/acc.xml", "w")
        if file then
            file.write([[
<Account>
    <Username>Default</Username>
    <Password>]] .. pass .. [[</Password>
    <Perm>Admin</Perm>
</Account>
<Account>
    <Username>Guest</Username>
    <Password></Password>
    <Perm>User</Perm>
</Account>
]])
            file.close()
        end
    end
    return 0
end
function validate(user_name, pass)
	local userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
    local userIndex = nil
    for index, user in ipairs(userlist) do
        if user == user_name then
            userIndex = index
            break
        end
    end
    if not userIndex then
        return 1 -- User Not Found
    end
    local correctPassword = DecryptPassword(passlist[userIndex])
    if pass ~= correctPassword then
        return 2 -- Password Incorrect
    end
    return 0
end
function getAccountPermission(user)
	userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
    local userIndex = nil
    for index, u in ipairs(userlist) do
        if u == user then
            userIndex = index
            break
        end
    end
    if not userIndex then
        return 1 -- User Not Found
    end
    return permlist[userIndex]
end
local function checkUsername(user)
	userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
    local upperUser = string.upper(user) -- Convert input username to uppercase
	if user == "" then
		return 1 -- Username can't be blank
	end
	if user == "N/A" then
		return 2 -- Can't use N/A for a username
	end
    if upperUser == "GUEST" then
        return 3 -- Can't Use Guest for a username
    end
    if upperUser == "DEFAULT" then
        return 5 -- Can't Use Guest for a username
    end
    for _, storedUser in ipairs(userlist) do
        if string.upper(storedUser) == upperUser then
            return 0 -- Return 0 if a match is found
        end
    end
    return 4 -- Return 4 if no match is found
end
function addAccount(user_name, pass, perm)
    local userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	local CheckUserResult = checkUsername(user_name)
    if CheckUserResult == 1 then
        return 1 -- Username can't be blank
    end
    if CheckUserResult == 2 then
        return 2 -- Can't use N/A for a username
    end
    if CheckUserResult == 3 then
        return 3 -- Can't Use Guest for a username
    end
    if perm ~= "User" and perm ~= "Admin" then
        return 4 -- Invalid permission level. Only 'User' or 'Admin' are allowed
    end
    if Account_Permission ~= "Admin" and SystemRan == false then
        return 5 -- Only Admins can create accounts
    end
    if CheckUserResult == 0 then
        return 6 -- Username already exists
    end
    if CheckUserResult == 5 then
        return 10 -- Can't Use Default for a username
    end
    local EncryptedPassword = EncryptPassword(pass)
    local accountEntry = string.format(
        [[
<Account>
    <Username>%s</Username>
    <Password>%s</Password>
    <Perm>%s</Perm>
</Account>
]], user_name, EncryptedPassword, perm)
    local file = fs.open("/crom/usr/acc.xml", "r")
    if not file then
        return 7 --Error Reading acc.xml
    end
    local content = file.readAll()
    file.close()
    local updatedContent = content .. "\n" .. accountEntry
    file = fs.open("/crom/usr/acc.xml", "w")
    file.write(updatedContent)
    file.close()
    if SystemRan then
        return 0 -- Account added successfully
    end
    local userDir = "crom/usr/" .. user_name
    local homeDir = userDir .. "/home"
    local function createDirIfNotExists(path)
        local testFile = fs.open(path .. "/testfile.tmp", "w")
        if testFile then
            testFile.close()
            fs.delete(path .. "/testfile.tmp")
            return true
        else
            return false
        end
    end
    if not createDirIfNotExists(userDir) then
        return 8 -- Error creating user directory
    end
    if not createDirIfNotExists(homeDir) then
        return 9 -- Error creating home directory
    end
	return 0 -- Account added successfully
end
function login(user,pass)
	userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	if Account_Username ~= "N/A" then
		return 3 -- Already logged in
	else
		local auth = validate(user,pass)
		if auth == 1 then
			return 1 -- User Not Found
		end
		if auth == 2 then
			return 2 -- Password Incorrect
		end
		Account_Username = user
		Account_Password = EncryptPassword(pass)
		Account_Permission = getAccountPermission(user)
		if Account_Permission == "User" then
			fs.setSystemReadOnly(true)
		end
		return 0 -- sucsess
	end
end
local function extractAndRemoveAccountBlock(username)
    local file = fs.open("/crom/usr/acc.xml", "r")
    if not file then
        return 1 -- "Error: Could not open file 
    end
    local content = file.readAll()
    file.close()
    local accountPattern = "<Account>.-</Account>"
    local accountBlock = nil
    local updatedContent = content
    local found = false
    for accountBlock in content:gmatch(accountPattern) do
        if accountBlock:match("<Username>" .. username .. "</Username>") then
            found = true
            updatedContent = updatedContent:gsub(accountBlock, "", 1)
            break
        end
    end
    if not found then
        return 2 -- Couldn't Find account thats trying to be removed
    end
    updatedContent = updatedContent:gsub("\n%s*\n", "\n") 
    updatedContent = updatedContent:gsub("\n%s*$", "\n") 
    file = fs.open("/crom/usr/acc.xml", "w")
    if not file then
        return 1 -- "Error: Could not open file 
    end
    file.write(updatedContent)
    file.close()
    return 0 -- Sucsess
end
local function deleteDirectory(path)
    if not fs.isDir(path) then
        return false
    end
    for _, file in ipairs(fs.list(path)) do
        local fullPath = path .. "/" .. file
        if fs.isDir(fullPath) then
            if not deleteDirectory(fullPath) then
                return false
            end
        else
            fs.delete(fullPath)
        end
    end
    fs.delete(path)
    return true
end
function deleteAccount(PassedUsername, PassedPassword)
    local userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	local CheckUserResult = checkUsername(PassedUsername)
    if CheckUserResult == 1 then
        return 1 -- Invalid username. It cannot be blank
    end
    if CheckUserResult == 2 then
        return 2 -- Invalid username. It cannot be N/A
    end
    if CheckUserResult == 3 then
        return 3 -- Invalid username. 'Guest' account cannot be deleted
    end
    if CheckUserResult == 5 and SystemRan == false then
        return 4 -- Cannot delete the Default account
    end
    if Account_Permission ~= "Admin" and SystemRan == false then
        return 5 -- Only Admins can delete accounts
    end
    if PassedUsername == Account_Username and SystemRan == false then
        return 6 -- Can't delete the account that is currently logged in
    end
    local validationResult = validate(PassedUsername, PassedPassword)
    if validationResult == 0 then
        local result = extractAndRemoveAccountBlock(PassedUsername)
        if result == 0 then
            local file = fs.open("/crom/usr/acc.xml", "r")
            if not file then
                return 7 -- Error opening acc.xml for reading/writing
            end
            local content = file.readAll()
            file.close()
            content = content:gsub("\n%s*\n", "\n") 
            content = content:gsub("\n%s*$", "\n") 
            file = fs.open("/crom/usr/acc.xml", "w")
            if not file then
                return 7 -- Error opening acc.xml for reading/writing
            end
            file.write(content)
            file.close()
            if not SystemRan then
                local userDir = "crom/usr/" .. PassedUsername
                if fs.exists(userDir) then
                    if not deleteDirectory(userDir) then
                        return 8 -- Error deleting directory
                    else
                        return 0 -- Sucsess
                    end
                else
                    return 9 -- Directory for the account does not exist.
                end
            else
                return 0 -- Sucsess
            end
        elseif result == 2 then
            return 10 -- Account does not exist
        end
    elseif validationResult == 1 then
        return 11 -- User not found
    elseif validationResult == 2 then
        return 12 -- Password incorrect
    end
end
function SysCall()
    return SystemRan
end
function changePassword(user, oldpass, newpass)
    userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	local CheckUserResult = checkUsername(user)
    if CheckUserResult == 3 then
        return 1 -- Invalid operation. Password for 'Guest' account cannot be changed
    end
    local validationResult = validate(user, oldpass)
    if validationResult == 0 then
        SystemRan = true
        fs.setReadOnlyFile("/crom/usr/acc.xml", false)
        local temp_perm = getAccountPermission(user)
        deleteAccount(user, oldpass)
        addAccount(user, newpass, temp_perm)
        if Account_Username == "User" then
            fs.setReadOnlyFile("/crom/usr/acc.xml", true)
        end
        SystemRan = false
		return 0 -- Sucsess
    elseif validationResult == 1 then
        return 2 -- User Not Found
    elseif validationResult == 2 then
        return 3 -- Incorrect Password
    end
end
function changePermissions(user, pass, newperm)
    userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	local CheckUserResult = checkUsername(user)
    if CheckUserResult == 3 then
        return 3 -- Invalid operation. Permissions for 'Guest' account cannot be changed.
    end
    if CheckUserResult == 5 then
        return 4 -- Invalid operation. Permissions for 'Default' account cannot be changed.
    end
    if newperm ~= "User" and newperm ~= "Admin" then
        return 6 -- Invalid permission level. Only 'User' or 'Admin' are allowed.
    end
	if Account_Permission == "Admin" then
		local validationResult = validate(user, pass)
		if validationResult == 0 then
			deleteAccount(user, pass)
			addAccount(user, pass, newperm)
			return 0 -- Sucsess
		elseif validationResult == 1 then
			return 1 -- User Not Found
		elseif validationResult == 2 then
			return 2 -- Incorrect Password 
		end
	else
		return 5 -- Only Admins can change permissions of an account
	end
end
local function copyDirectory(sourceDir, targetDir)
    if not fs.exists(sourceDir) then
        return false
    end
    if fs.exists(targetDir) then
        return false
    end
    fs.makeDir(targetDir)
    for _, file in ipairs(fs.list(sourceDir)) do
        local sourcePath = sourceDir .. "/" .. file
        local targetPath = targetDir .. "/" .. file
        if fs.isDir(sourcePath) then
            if not copyDirectory(sourcePath, targetPath) then
                return false
            end
        else
            fs.copy(sourcePath, targetPath)
        end
    end
    return true
end
function changeUsername(olduser, pass, newuser)
    userlist, passlist, permlist = parseUserFile("/crom/usr/acc.xml")
	local CheckUserResult = checkUsername(olduser)
	local CheckUser_Result = checkUsername(newuser)
    if CheckUserResult == 3 then
        return 3 -- Can't change Guest account username
    end
    if CheckUser_Result == 5 then
        return 4 -- Can't change account name to Default
    end
    if CheckUser_Result == 1 then 
        return 5 -- Can't change account name to blank
    end
    if CheckUser_Result == 2 then 
        return 6 -- Can't change account name to N/A
    end
    if CheckUser_Result == 0 then 
        return 7 -- Username Already Exists
    end
    local validationResult = validate(olduser, pass)
    if validationResult == 0 then
        SystemRan = true
        fs.setReadOnlyFile("/crom/usr/acc.xml", false)
        PERM = getAccountPermission(olduser)
        deleteAccount(olduser, pass)
        addAccount(newuser, pass, PERM)
        if username == olduser then
            username = newuser
        end
        local oldDir = "crom/usr/" .. olduser
        local newDir = "crom/usr/" .. newuser
        if fs.exists(oldDir) then
            if copyDirectory(oldDir, newDir) then
                deleteDirectory(oldDir)
            else
				return 8 -- Error renaming user directory
            end
        end
        if getAccountPermission(Account_Username) == "User" then
            fs.setReadOnlyFile("/crom/usr/acc.xml", true)
        end
        SystemRan = false
		return 0 -- Sucsess
    elseif validationResult == 1 then
        return 1 -- User Not Found
    elseif validationResult == 2 then
        return 2 -- Incorrect Password
    end
end
function logout()
	os.reboot()
end
return fkernel
