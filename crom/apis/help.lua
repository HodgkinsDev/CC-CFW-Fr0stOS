local expect = dofile("crom/modules/main/cc/expect.lua").expect
local sPath = "/crom/help"
function path()
    return sPath
end
function setPath(_sPath)
    expect(1, _sPath, "string")
    sPath = _sPath
end
local extensions = { "", ".md", ".txt" }
function lookup(topic)
    expect(1, topic, "string")
    for path in string.gmatch(sPath, "[^:]+") do
        path = fs.combine(path, topic)
        for _, extension in ipairs(extensions) do
            local file = path .. extension
            if fs.exists(file) and not fs.isDir(file) then
                return file
            end
        end
    end
    return nil
end
function topics()
    local tItems = {
        ["index"] = true,
    }
    for sPath in string.gmatch(sPath, "[^:]+") do
        if fs.isDir(sPath) then
            local tList = fs.list(sPath)
            for _, sFile in pairs(tList) do
                if string.sub(sFile, 1, 1) ~= "." then
                    if not fs.isDir(fs.combine(sPath, sFile)) then
                        for i = 2, #extensions do
                            local extension = extensions[i]
                            if #sFile > #extension and sFile:sub(-#extension) == extension then
                                sFile = sFile:sub(1, -#extension - 1)
                            end
                        end
                        tItems[sFile] = true
                    end
                end
            end
        end
    end
    local tItemList = {}
    for sItem in pairs(tItems) do
        table.insert(tItemList, sItem)
    end
    table.sort(tItemList)
    return tItemList
end
function completeTopic(sText)
    expect(1, sText, "string")
    local tTopics = topics()
    local tResults = {}
    for n = 1, #tTopics do
        local sTopic = tTopics[n]
        if #sTopic > #sText and string.sub(sTopic, 1, #sText) == sText then
            table.insert(tResults, string.sub(sTopic, #sText + 1))
        end
    end
    return tResults
end