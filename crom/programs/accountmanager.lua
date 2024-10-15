local function AdminMenu()
	print("[1]Add account")
	print("[2]Delete account")
	print("[3]Change account password")
	print("[4]Change account username")
	print("[5]Change account permission")
	print("[6]Get specific account permission")
	print("[7]Exit")
end
local function UserMenu()
	print("[1]Change account password")
	print("[2]Change account username")
	print("[3]Get specific account permission")
	print("[4]Exit")
end
local function ttl()
print("Fr0stOS Account Manager")
print("---------------------------------------------------")
print("Current User:" .. fkernel.getUsername())
print("Current Premission Level:" .. fkernel.getPermissions())
print("---------------------------------------------------")
end

while true do
	shell.run("clear")
	ttl()
	local perm = fkernel.getPermissions()
	if perm == "Admin" then
		AdminMenu()
	else
		UserMenu()
	end
	print("")
	io.write("Choice:")
	local input = io.read()
	if input == "1" and perm == "User" or input == "3" and perm == "Admin" then
		shell.run("clear")
		ttl()
		io.write("Account username:")
		local usr = io.read()
		io.write("\nAccount old password:")
		local oldpass = io.read()
		io.write("\nAccount new password:")
		local newpss = io.read()
		local result = fkernel.changePassword(usr,oldpass,newpss)
		if result == 2 then
			term.setTextColor(colors.red)
			print("\nUsername not found")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 3 then
			term.setTextColor(colors.red)
			print("\nIncorrect password")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 1 then
			term.setTextColor(colors.red)
			print("\nCan't change Guest account password")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 0 then
			term.setTextColor(colors.green)
			print("\nPassword changed!")
			term.setTextColor(colors.white)
			sleep(2)
		end
	end
	if input == "2" and perm == "User" or input == "4" and perm == "Admin" then
		shell.run("clear")
		ttl()
		io.write("Account username:")
		local usr = io.read()
		io.write("\nAccount password:")
		local pass = io.read()
		io.write("\nAccount new username:")
		local newusername = io.read()
		local results = fkernel.changeUsername(usr,pass,newusername)
		if results == 1 then
			term.setTextColor(colors.red)
			print("\nUsername not found")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 2 then
			term.setTextColor(colors.red)
			print("\nIncorrect password")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 3 then
			term.setTextColor(colors.red)
			print("\nCan't change Guest account username")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 4 then
			term.setTextColor(colors.red)
			print("\nCan't change account name to Default")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 5 then
			term.setTextColor(colors.red)
			print("\nCan't change account name to blank")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 6 then
			term.setTextColor(colors.red)
			print("\nCan't change account name to N/A")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 7 then
			term.setTextColor(colors.red)
			print("\nUsername Already Exists")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if results == 0 then
			term.setTextColor(colors.green)
			print("\nUsername changed!")
			term.setTextColor(colors.white)
			sleep(2)
		end
	end
	if input == "4" and perm == "User" or input == "7" and perm == "Admin" then break end
	if input == "1" and perm == "Admin" then
		shell.run("clear")
		ttl()
		io.write("New account username:")
		local usr = io.read()
		io.write("\nNew account password:")
		local newaccpass = io.read()
		io.write("\nNew account permission:")
		local acc_permission = io.read()
		local result = fkernel.addAccount(usr,newaccpass,acc_permission)
		if result == 1 then
			term.setTextColor(colors.red)
			print("\nUsername can't be blank")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 2 then
			term.setTextColor(colors.red)
			print("\nCan't use N/A for a username")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 3 then
			term.setTextColor(colors.red)
			print("\nCan't Use Guest for a username")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 4 then
			term.setTextColor(colors.red)
			print("\nInvalid permission level. Only 'User' or 'Admin' are allowed")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 6 then
			term.setTextColor(colors.red)
			print("\nUsername already exists")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 10 then
			term.setTextColor(colors.red)
			print("\nCan't Use Default for a username")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 0 then
			term.setTextColor(colors.green)
			print("\nAccount added!")
			term.setTextColor(colors.white)
			sleep(2)
		end
	end
	if input == "2" and perm == "Admin" then
		shell.run("clear")
		ttl()
		io.write("Account username:")
		local usr = io.read()
		io.write("\nAccount password:")
		local accpass = io.read()
		local result = fkernel.deleteAccount(usr,accpass)
		if result == 1 then
			term.setTextColor(colors.red)
			print("\nUsername can't be blank")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 2 then
			term.setTextColor(colors.red)
			print("\nCan't use N/A for a username")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 3 then
			term.setTextColor(colors.red)
			print("\nInvalid username. 'Guest' account cannot be deleted")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 4 then
			term.setTextColor(colors.red)
			print("\nInvalid username. 'Default' account cannot be deleted")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 6 then
			term.setTextColor(colors.red)
			print("\nCan't delete the account that is currently logged in")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 11 then
			term.setTextColor(colors.red)
			print("\nUser not found")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 12 then
			term.setTextColor(colors.red)
			print("\nPassword incorrect")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 10 then
			term.setTextColor(colors.red)
			print("\nAccount does not exist")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 0 then
			term.setTextColor(colors.green)
			print("\nAccount deleted!")
			term.setTextColor(colors.white)
			sleep(2)
		end
	end
	if input == "6" and perm == "Admin" or input == "3" and perm == "User" then
		shell.run("clear")
		ttl()
		io.write("Account username:")
		local usr = io.read()
		userperm = fkernel.getAccountPermission(usr)
		if userperm == 1 then
			term.setTextColor(colors.red)
			print("\nAccount does not exist")
			term.setTextColor(colors.white)
			sleep(2)
		else
			print("\n" ..userperm)
			sleep(2)
		end
	end
	if input == "5" and perm == "Admin" then
		shell.run("clear")
		ttl()
		io.write("Account username:")
		local usr = io.read()
		io.write("\nAccount password:")
		local newaccpass = io.read()
		io.write("\nNew permission:")
		local acc_permission = io.read()
		local result = fkernel.changePermissions(usr,newaccpass,acc_permission)
		if result == 3 then
			term.setTextColor(colors.red)
			print("\nInvalid operation. Permissions for 'Guest' account cannot be changed.")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 4 then
			term.setTextColor(colors.red)
			print("\nInvalid operation. Permissions for 'Default' account cannot be changed.")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 6 then
			term.setTextColor(colors.red)
			print("\nInvalid permission level. Only 'User' or 'Admin' are allowed.")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 1 then
			term.setTextColor(colors.red)
			print("\nUser Not Found")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 2 then
			term.setTextColor(colors.red)
			print("\nIncorrect Password")
			term.setTextColor(colors.white)
			sleep(2)
		end
		if result == 0 then
			term.setTextColor(colors.green)
			print("\nPermission changed!")
			term.setTextColor(colors.white)
			sleep(2)
		end
	end
end