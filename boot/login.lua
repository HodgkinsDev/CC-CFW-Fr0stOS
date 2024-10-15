local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function bl()
    print("")
end

local function ttl()
    local versionText = "Fr0stOS " .. fkernel.getVersion()
    local idText = "Computer ID:" .. os.computerID()
    local width = term and term.getSize() or 51
    local spaces = width - #versionText - #idText
    return versionText .. string.rep(" ", spaces) .. idText
end

while true do
    clear()
    print(ttl())
    print("\nPlease Login")
    bl()
    io.write("Username:")
    local username = io.read()
	bl()
    io.write("Password:")
    local password = io.read()
    local result = fkernel.login(username, password)
    bl()
    if result == 1 then
        print("Username not Found")
        sleep(2)
    elseif result == 2 then
        print("Password Incorrect")
        sleep(2)
    elseif result == 0 then
		shell.reset_term()
        break -- This breaks the loop after successful login
    end
end
