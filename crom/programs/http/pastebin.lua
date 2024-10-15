local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " put <filename>")
    print(programName .. " get <code> <filename>")
    print(programName .. " run <code> <arguments>")
end
local tArgs = { ... }
if #tArgs < 2 then
    printUsage()
    return
end
if not http then
    printError("Pastebin requires the http API, but it is not enabled")
    printError("Set http.enabled to true in CC: Tweaked's server config")
    return
end
local function extractId(paste)
    local patterns = {
        "^([%a%d]+)$",
        "^https?://pastebin.com/([%a%d]+)$",
        "^pastebin.com/([%a%d]+)$",
        "^https?://pastebin.com/raw/([%a%d]+)$",
        "^pastebin.com/raw/([%a%d]+)$",
    }
    for i = 1, #patterns do
        local code = paste:match(patterns[i])
        if code then return code end
    end
    return nil
end
local function get(url)
    local paste = extractId(url)
    if not paste then
        io.stderr:write("Invalid pastebin code.\n")
        io.write("The code is the ID at the end of the pastebin.com URL.\n")
        return
    end
    write("Connecting to pastebin.com... ")
    local cacheBuster = ("%x"):format(math.random(0, 2 ^ 30))
    local response, err = http.get(
        "https://pastebin.com/raw/" .. textutils.urlEncode(paste) .. "?cb=" .. cacheBuster
    )
    if response then
        local headers = response.getResponseHeaders()
        if not headers["Content-Type"] or not headers["Content-Type"]:find("^text/plain") then
            io.stderr:write("Failed.\n")
            print("Pastebin blocked the download due to spam protection. Please complete the captcha in a web browser: https://pastebin.com/" .. textutils.urlEncode(paste))
            return
        end
        print("Success.")
        local sResponse = response.readAll()
        response.close()
        return sResponse
    else
        io.stderr:write("Failed.\n")
        print(err)
    end
end
local sCommand = tArgs[1]
if sCommand == "put" then
    local sFile = tArgs[2]
    local sPath = shell.resolve(sFile)
    if not fs.exists(sPath) or fs.isDir(sPath) then
        print("No such file")
        return
    end
    local sName = fs.getName(sPath)
    local file = fs.open(sPath, "r")
    local sText = file.readAll()
    file.close()
    write("Connecting to pastebin.com... ")
    local key = "0ec2eb25b6166c0c27a394ae118ad829"
    local response = http.post(
        "https://pastebin.com/api/api_post.php",
        "api_option=paste&" ..
        "api_dev_key=" .. key .. "&" ..
        "api_paste_format=lua&" ..
        "api_paste_name=" .. textutils.urlEncode(sName) .. "&" ..
        "api_paste_code=" .. textutils.urlEncode(sText)
    )
    if response then
        print("Success.")
        local sResponse = response.readAll()
        response.close()
        local sCode = string.match(sResponse, "[^/]+$")
        print("Uploaded as " .. sResponse)
        print("Run \"pastebin get " .. sCode .. "\" to download anywhere")
    else
        print("Failed.")
    end
elseif sCommand == "get" then
    if #tArgs < 3 then
        printUsage()
        return
    end
    local sCode = tArgs[2]
    local sFile = tArgs[3]
    local sPath = shell.resolve(sFile)
    if fs.exists(sPath) then
        print("File already exists")
        return
    end
    local res = get(sCode)
    if res then
        local file = fs.open(sPath, "w")
        file.write(res)
        file.close()
        print("Downloaded as " .. sFile)
    end
elseif sCommand == "run" then
    local sCode = tArgs[2]
    local res = get(sCode)
    if res then
        local func, err = load(res, sCode, "t", _ENV)
        if not func then
            printError(err)
            return
        end
        local success, msg = pcall(func, select(3, ...))
        if not success then
            printError(msg)
        end
    end
else
    printUsage()
    return
end