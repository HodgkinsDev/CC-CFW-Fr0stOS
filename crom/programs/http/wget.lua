local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usage:")
    print(programName .. " <url> [filename]")
    print(programName .. " run <url>")
end
local function silentWgetRun(url)
    if not http then
        return nil, "HTTP API is not available."
    end

    local ok, err = http.checkURL(url)
    if not ok then
        return nil, err or "Invalid URL."
    end

    local response = http.get(url)
    if not response then
        return nil, "Failed to fetch the URL."
    end

    local content = response.readAll()
    response.close()

    local func, loadErr = load(content, url, "t", _ENV)
    if not func then
        return nil, loadErr
    end

    local success, execErr = pcall(func)
    if not success then
        return nil, execErr
    end

    return true
end
local tArgs = { ... }
local run = false
if tArgs[1] == "run" then
    table.remove(tArgs, 1)
    run = true
end
if tArgs[1] == "runSilent" then
	silentWgetRun(tArgs[2])
	return
end
if #tArgs < 1 then
    printUsage()
    return
end
local url = table.remove(tArgs, 1)
if not http then
    printError("wget requires the http API, but it is not enabled")
    printError("Set http.enabled to true in CC: Tweaked's server config")
    return
end
local function getFilename(sUrl)
    sUrl = sUrl:gsub("[#?].*" , ""):gsub("/+$" , "")
    return sUrl:match("/([^/]+)$")
end
local function get(sUrl)
    local ok, err = http.checkURL(url)
    if not ok then
        printError(err or "Invalid URL.")
        return
    end
    write("Connecting to " .. sUrl .. "... ")
    local response = http.get(sUrl)
    if not response then
        print("Failed.")
        return nil
    end
    print("Success.")
    local sResponse = response.readAll()
    response.close()
    return sResponse or ""
end
if run then
    local res = get(url)
    if not res then return end
    local func, err = load(res, getFilename(url), "t", _ENV)
    if not func then
        printError(err)
        return
    end
    local ok, err = pcall(func, table.unpack(tArgs))
    if not ok then
        printError(err)
    end
else
    local sFile = tArgs[1] or getFilename(url) or url
    local sPath = shell.resolve(sFile)
    if fs.exists(sPath) then
        print("File already exists")
        return
    end
    local res = get(url)
    if not res then return end
    local file, err = fs.open(sPath, "wb")
    if not file then
        printError("Cannot save file: " .. err)
        return
    end
    file.write(res)
    file.close()
    print("Downloaded as " .. sFile)
end