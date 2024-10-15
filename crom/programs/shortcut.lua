function verifyPaths(filePath, dirPath, newFileName)
    -- Check if filePath starts with a character other than '/'
    if filePath:sub(1, 1) ~= '/' then
        return 6  -- File path must start with '/'
    end

    -- Check if dirPath starts with a character other than '/'
    if dirPath:sub(1, 1) ~= '/' then
        return 6  -- Directory path must start with '/'
    end

    -- Check if the last character of filePath is '/'
    if filePath:sub(-1) == '/' then
        return 5  -- File path must not end with '/'
    end

    -- Check if the file path is a directory
    if fs.isDir(filePath) then
        return 1  -- File path is a directory
    end
    
    -- Check if the file path exists
    if not fs.exists(filePath) then
        return 2  -- File does not exist
    end

    -- Check if the last character of dirPath is '/'
    if dirPath:sub(-1) ~= '/' then
        return 3  -- Directory path must end with '/'
    end
    
    -- Check if the directory path exists
    if not fs.isDir(dirPath) then
        -- Create the directory if it doesn't exist
        shell.run("mkdir " .. dirPath)  -- Correctly calls mkdir with the directory path
    end

    -- Check if the new file name is valid (not empty)
    if newFileName == "" then
        return 4  -- Invalid new file name
    end

    -- If all checks pass, return 0
    return 0
end

function verifyDIRPaths(dirPath1, dirPath2, fileName)
    -- Check if dirPath1 starts with a character other than '/'
    if dirPath1:sub(1, 1) ~= '/' then
        return 7  -- dirPath1 must start with '/'
    end

    -- Check if dirPath2 starts with a character other than '/'
    if dirPath2:sub(1, 1) ~= '/' then
        return 7  -- dirPath2 must start with '/'
    end

    -- Check if the last character of dirPath1 is '/'
    if dirPath1:sub(-1) ~= '/' then
        return 8  -- dirPath1 must end with '/'
    end

    -- Check if the last character of dirPath2 is '/'
    if dirPath2:sub(-1) ~= '/' then
        return 8  -- dirPath2 must end with '/'
    end

    -- Check if dirPath1 exists
    if not fs.isDir(dirPath1) then
        return 9  -- dirPath1 does not exist
    end

    -- Check if dirPath2 exists
    if not fs.isDir(dirPath2) then
        -- Create dirPath2 if it doesn't exist
        local success, err = shell.run("mkdir " .. dirPath2)  -- Create directory
        if not success then
            print("Error creating directory:", err)  -- Print the error if mkdir fails
        end
    end

    -- Check if the file name is valid (not empty)
    if fileName == "" then
        return 4  -- Invalid file name
    end

    -- If all checks pass, return 0
    return 0
end
function ErrorPrint(ec)
    -- Save the current text color
    local originalColor = term.getTextColor()
	term.setTextColor(colors.red)
    if ec == 1 then
        print("Error:File path can't be a DIR")
    end
	if ec == 2 then
		print("Error:File doesn't exist")
	end
	if ec == 3 then
		print("Error:DIR path must be a directory")
	end
	if ec == 4 then
		print("Error:File name can't be blank")
	end
	if ec == 5 then
		print("Error:File path can't be a directory")
	end
	if ec == 6 then
		print("Error:File path or DIR path must start with /")
	end
    if ec == 7 then
        print("Error:First and second dirpath must start with /")
    end
	if ec == 8 then
		print("Error:First and second dirpath must end with /")
	end
	if ec == 9 then
		print("Error:DIR to make shortcut doesn't exist")
	end
    -- Reset text color to original
    term.setTextColor(originalColor)
end

function makeFileShortcut(ShortcutFile, ShortcutLoc, FileName)
    local result = verifyPaths(ShortcutFile, ShortcutLoc, FileName)
    if result == 0 then
        -- Concatenate ShortcutLoc and FileName
        local fullShortcutPath = ShortcutLoc .. FileName .. ".fsc"

        -- Create the new shortcut file and write the passed text
        local shortcutFileHandle = fs.open(fullShortcutPath, "w")  -- Open for writing
        shortcutFileHandle.writeLine(ShortcutFile)  -- Write the passed text as the first line
        shortcutFileHandle.close()  -- Close the shortcut file
    else
        ErrorPrint(result)  -- Handle error from verifyPathss
    end
end

function makeDIRShortcut(ShortcutDIR,ShortcutLocDIR,FN)
	local result = verifyDIRPaths(ShortcutDIR, ShortcutLocDIR, FN)
	if result == 0 then
		local fullShortcutPath = ShortcutLocDIR .. FN .. ".dsc"
		local shortcutFileHandle = fs.open(fullShortcutPath, "w")
		shortcutFileHandle.writeLine(ShortcutDIR)
		shortcutFileHandle.close()
	else
		ErrorPrint(result)
	end
end

local args = {...}
if #args ~= 4 then
	print("Usage: <function> <shortcutfile/DIR location> <shortcutfile/DIR save location> <shortcut name>")
	return
end
if args[1] ~= "File" and args[1] ~= "file" and args[1] ~= "DIR" and args[1] ~= "dir" then
    print("Function can only be File/file or DIR/dir\n")
    print("Usage: <function> <shortcut file/DIR location> <shortcut file/DIR save location> <shortcut name>")
    return
end
if args[1] == "File" or args[1] == "file" then
	makeFileShortcut(args[2],args[3],arg[4])
end
if args[1] == "DIR" or args[1] == "dir" then
	makeDIRShortcut(args[2],args[3],arg[4])
end