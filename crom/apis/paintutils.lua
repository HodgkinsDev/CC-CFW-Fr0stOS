local expect = dofile("crom/modules/main/cc/expect.lua").expect
local function drawPixelInternal(xPos, yPos)
    term.setCursorPos(xPos, yPos)
    term.write(" ")
end
local tColourLookup = {}
for n = 1, 16 do
    tColourLookup[string.byte("0123456789abcdef", n, n)] = 2 ^ (n - 1)
end
local function parseLine(tImageArg, sLine)
    local tLine = {}
    for x = 1, sLine:len() do
        tLine[x] = tColourLookup[string.byte(sLine, x, x)] or 0
    end
    table.insert(tImageArg, tLine)
end
local function sortCoords(startX, startY, endX, endY)
    local minX, maxX, minY, maxY
    if startX <= endX then
        minX, maxX = startX, endX
    else
        minX, maxX = endX, startX
    end
    if startY <= endY then
        minY, maxY = startY, endY
    else
        minY, maxY = endY, startY
    end
    return minX, maxX, minY, maxY
end
function parseImage(image)
    expect(1, image, "string")
    local tImage = {}
    for sLine in (image .. "\n"):gmatch("(.-)\n") do
        parseLine(tImage, sLine)
    end
    return tImage
end
function loadImage(path)
    expect(1, path, "string")
    if fs.exists(path) then
        local file = io.open(path, "r")
        local sContent = file:read("*a")
        file:close()
        return parseImage(sContent)
    end
    return nil
end
function drawPixel(xPos, yPos, colour)
    expect(1, xPos, "number")
    expect(2, yPos, "number")
    expect(3, colour, "number", "nil")
    if colour then
        term.setBackgroundColor(colour)
    end
    return drawPixelInternal(xPos, yPos)
end
function drawLine(startX, startY, endX, endY, colour)
    expect(1, startX, "number")
    expect(2, startY, "number")
    expect(3, endX, "number")
    expect(4, endY, "number")
    expect(5, colour, "number", "nil")
    startX = math.floor(startX)
    startY = math.floor(startY)
    endX = math.floor(endX)
    endY = math.floor(endY)
    if colour then
        term.setBackgroundColor(colour)
    end
    if startX == endX and startY == endY then
        drawPixelInternal(startX, startY)
        return
    end
    local minX = math.min(startX, endX)
    local maxX, minY, maxY
    if minX == startX then
        minY = startY
        maxX = endX
        maxY = endY
    else
        minY = endY
        maxX = startX
        maxY = startY
    end
    local xDiff = maxX - minX
    local yDiff = maxY - minY
    if xDiff > math.abs(yDiff) then
        local y = minY
        local dy = yDiff / xDiff
        for x = minX, maxX do
            drawPixelInternal(x, math.floor(y + 0.5))
            y = y + dy
        end
    else
        local x = minX
        local dx = xDiff / yDiff
        if maxY >= minY then
            for y = minY, maxY do
                drawPixelInternal(math.floor(x + 0.5), y)
                x = x + dx
            end
        else
            for y = minY, maxY, -1 do
                drawPixelInternal(math.floor(x + 0.5), y)
                x = x - dx
            end
        end
    end
end
function drawBox(startX, startY, endX, endY, nColour)
    expect(1, startX, "number")
    expect(2, startY, "number")
    expect(3, endX, "number")
    expect(4, endY, "number")
    expect(5, nColour, "number", "nil")
    startX = math.floor(startX)
    startY = math.floor(startY)
    endX = math.floor(endX)
    endY = math.floor(endY)
    if nColour then
        term.setBackgroundColor(nColour) 
    else
        nColour = term.getBackgroundColour()
    end
    local colourHex = colours.toBlit(nColour)
    if startX == endX and startY == endY then
        drawPixelInternal(startX, startY)
        return
    end
    local minX, maxX, minY, maxY = sortCoords(startX, startY, endX, endY)
    local width = maxX - minX + 1
    for y = minY, maxY do
        if y == minY or y == maxY then
            term.setCursorPos(minX, y)
            term.blit((" "):rep(width), colourHex:rep(width), colourHex:rep(width))
        else
            term.setCursorPos(minX, y)
            term.blit(" ", colourHex, colourHex)
            term.setCursorPos(maxX, y)
            term.blit(" ", colourHex, colourHex)
        end
    end
end
function drawFilledBox(startX, startY, endX, endY, nColour)
    expect(1, startX, "number")
    expect(2, startY, "number")
    expect(3, endX, "number")
    expect(4, endY, "number")
    expect(5, nColour, "number", "nil")
    startX = math.floor(startX)
    startY = math.floor(startY)
    endX = math.floor(endX)
    endY = math.floor(endY)
    if nColour then
        term.setBackgroundColor(nColour) 
    else
        nColour = term.getBackgroundColour()
    end
    local colourHex = colours.toBlit(nColour)
    if startX == endX and startY == endY then
        drawPixelInternal(startX, startY)
        return
    end
    local minX, maxX, minY, maxY = sortCoords(startX, startY, endX, endY)
    local width = maxX - minX + 1
    for y = minY, maxY do
        term.setCursorPos(minX, y)
        term.blit((" "):rep(width), colourHex:rep(width), colourHex:rep(width))
    end
end
function drawImage(image, xPos, yPos)
    expect(1, image, "table")
    expect(2, xPos, "number")
    expect(3, yPos, "number")
    for y = 1, #image do
        local tLine = image[y]
        for x = 1, #tLine do
            if tLine[x] > 0 then
                term.setBackgroundColor(tLine[x])
                drawPixelInternal(x + xPos - 1, y + yPos - 1)
            end
        end
    end
end