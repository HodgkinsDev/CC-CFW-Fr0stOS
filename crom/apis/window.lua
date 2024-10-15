local expect = dofile("crom/modules/main/cc/expect.lua").expect
local tHex = {
    [colors.white] = "0",
    [colors.orange] = "1",
    [colors.magenta] = "2",
    [colors.lightBlue] = "3",
    [colors.yellow] = "4",
    [colors.lime] = "5",
    [colors.pink] = "6",
    [colors.gray] = "7",
    [colors.lightGray] = "8",
    [colors.cyan] = "9",
    [colors.purple] = "a",
    [colors.blue] = "b",
    [colors.brown] = "c",
    [colors.green] = "d",
    [colors.red] = "e",
    [colors.black] = "f",
}
local type = type
local string_rep = string.rep
local string_sub = string.sub
local function parse_color(color)
    if type(color) ~= "number" then
        return expect(1, color, "number")
    end
    if color < 0 or color > 0xffff then error("Colour out of range", 3) end
    return 2 ^ math.floor(math.log(color, 2))
end
function create(parent, nX, nY, nWidth, nHeight, bStartVisible)
    expect(1, parent, "table")
    expect(2, nX, "number")
    expect(3, nY, "number")
    expect(4, nWidth, "number")
    expect(5, nHeight, "number")
    expect(6, bStartVisible, "boolean", "nil")
    if parent == term then
        error("term is not a recommended window parent, try term.current() instead", 2)
    end
    local sEmptySpaceLine
    local tEmptyColorLines = {}
    local function createEmptyLines(nWidth)
        sEmptySpaceLine = string_rep(" ", nWidth)
        for n = 0, 15 do
            local nColor = 2 ^ n
            local sHex = tHex[nColor]
            tEmptyColorLines[nColor] = string_rep(sHex, nWidth)
        end
    end
    createEmptyLines(nWidth)
    local bVisible = bStartVisible ~= false
    local nCursorX = 1
    local nCursorY = 1
    local bCursorBlink = false
    local nTextColor = colors.white
    local nBackgroundColor = colors.black
    local tLines = {}
    local tPalette = {}
    do
        local sEmptyText = sEmptySpaceLine
        local sEmptyTextColor = tEmptyColorLines[nTextColor]
        local sEmptyBackgroundColor = tEmptyColorLines[nBackgroundColor]
        for y = 1, nHeight do
            tLines[y] = { sEmptyText, sEmptyTextColor, sEmptyBackgroundColor }
        end
        for i = 0, 15 do
            local c = 2 ^ i
            tPalette[c] = { parent.getPaletteColour(c) }
        end
    end
    local function updateCursorPos()
        if nCursorX >= 1 and nCursorY >= 1 and
           nCursorX <= nWidth and nCursorY <= nHeight then
            parent.setCursorPos(nX + nCursorX - 1, nY + nCursorY - 1)
        else
            parent.setCursorPos(0, 0)
        end
    end
    local function updateCursorBlink()
        parent.setCursorBlink(bCursorBlink)
    end
    local function updateCursorColor()
        parent.setTextColor(nTextColor)
    end
    local function redrawLine(n)
        local tLine = tLines[n]
        parent.setCursorPos(nX, nY + n - 1)
        parent.blit(tLine[1], tLine[2], tLine[3])
    end
    local function redraw()
        for n = 1, nHeight do
            redrawLine(n)
        end
    end
    local function updatePalette()
        for k, v in pairs(tPalette) do
            parent.setPaletteColour(k, v[1], v[2], v[3])
        end
    end
    local function internalBlit(sText, sTextColor, sBackgroundColor)
        local nStart = nCursorX
        local nEnd = nStart + #sText - 1
        if nCursorY >= 1 and nCursorY <= nHeight then
            if nStart <= nWidth and nEnd >= 1 then
                local tLine = tLines[nCursorY]
                if nStart == 1 and nEnd == nWidth then
                    tLine[1] = sText
                    tLine[2] = sTextColor
                    tLine[3] = sBackgroundColor
                else
                    local sClippedText, sClippedTextColor, sClippedBackgroundColor
                    if nStart < 1 then
                        local nClipStart = 1 - nStart + 1
                        local nClipEnd = nWidth - nStart + 1
                        sClippedText = string_sub(sText, nClipStart, nClipEnd)
                        sClippedTextColor = string_sub(sTextColor, nClipStart, nClipEnd)
                        sClippedBackgroundColor = string_sub(sBackgroundColor, nClipStart, nClipEnd)
                    elseif nEnd > nWidth then
                        local nClipEnd = nWidth - nStart + 1
                        sClippedText = string_sub(sText, 1, nClipEnd)
                        sClippedTextColor = string_sub(sTextColor, 1, nClipEnd)
                        sClippedBackgroundColor = string_sub(sBackgroundColor, 1, nClipEnd)
                    else
                        sClippedText = sText
                        sClippedTextColor = sTextColor
                        sClippedBackgroundColor = sBackgroundColor
                    end
                    local sOldText = tLine[1]
                    local sOldTextColor = tLine[2]
                    local sOldBackgroundColor = tLine[3]
                    local sNewText, sNewTextColor, sNewBackgroundColor
                    if nStart > 1 then
                        local nOldEnd = nStart - 1
                        sNewText = string_sub(sOldText, 1, nOldEnd) .. sClippedText
                        sNewTextColor = string_sub(sOldTextColor, 1, nOldEnd) .. sClippedTextColor
                        sNewBackgroundColor = string_sub(sOldBackgroundColor, 1, nOldEnd) .. sClippedBackgroundColor
                    else
                        sNewText = sClippedText
                        sNewTextColor = sClippedTextColor
                        sNewBackgroundColor = sClippedBackgroundColor
                    end
                    if nEnd < nWidth then
                        local nOldStart = nEnd + 1
                        sNewText = sNewText .. string_sub(sOldText, nOldStart, nWidth)
                        sNewTextColor = sNewTextColor .. string_sub(sOldTextColor, nOldStart, nWidth)
                        sNewBackgroundColor = sNewBackgroundColor .. string_sub(sOldBackgroundColor, nOldStart, nWidth)
                    end
                    tLine[1] = sNewText
                    tLine[2] = sNewTextColor
                    tLine[3] = sNewBackgroundColor
                end
                if bVisible then
                    redrawLine(nCursorY)
                end
            end
        end
        nCursorX = nEnd + 1
        if bVisible then
            updateCursorColor()
            updateCursorPos()
        end
    end
    local window = {}
    function window.write(sText)
        sText = tostring(sText)
        internalBlit(sText, string_rep(tHex[nTextColor], #sText), string_rep(tHex[nBackgroundColor], #sText))
    end
    function window.blit(sText, sTextColor, sBackgroundColor)
        if type(sText) ~= "string" then expect(1, sText, "string") end
        if type(sTextColor) ~= "string" then expect(2, sTextColor, "string") end
        if type(sBackgroundColor) ~= "string" then expect(3, sBackgroundColor, "string") end
        if #sTextColor ~= #sText or #sBackgroundColor ~= #sText then
            error("Arguments must be the same length", 2)
        end
        sTextColor = sTextColor:lower()
        sBackgroundColor = sBackgroundColor:lower()
        internalBlit(sText, sTextColor, sBackgroundColor)
    end
    function window.clear()
        local sEmptyText = sEmptySpaceLine
        local sEmptyTextColor = tEmptyColorLines[nTextColor]
        local sEmptyBackgroundColor = tEmptyColorLines[nBackgroundColor]
        for y = 1, nHeight do
            local line = tLines[y]
            line[1] = sEmptyText
            line[2] = sEmptyTextColor
            line[3] = sEmptyBackgroundColor
        end
        if bVisible then
            redraw()
            updateCursorColor()
            updateCursorPos()
        end
    end
    function window.clearLine()
        if nCursorY >= 1 and nCursorY <= nHeight then
            local line = tLines[nCursorY]
            line[1] = sEmptySpaceLine
            line[2] = tEmptyColorLines[nTextColor]
            line[3] = tEmptyColorLines[nBackgroundColor]
            if bVisible then
                redrawLine(nCursorY)
                updateCursorColor()
                updateCursorPos()
            end
        end
    end
    function window.getCursorPos()
        return nCursorX, nCursorY
    end
    function window.setCursorPos(x, y)
        if type(x) ~= "number" then expect(1, x, "number") end
        if type(y) ~= "number" then expect(2, y, "number") end
        nCursorX = math.floor(x)
        nCursorY = math.floor(y)
        if bVisible then
            updateCursorPos()
        end
    end
    function window.setCursorBlink(blink)
        if type(blink) ~= "boolean" then expect(1, blink, "boolean") end
        bCursorBlink = blink
        if bVisible then
            updateCursorBlink()
        end
    end
    function window.getCursorBlink()
        return bCursorBlink
    end
    local function isColor()
        return parent.isColor()
    end
    function window.isColor()
        return isColor()
    end
    function window.isColour()
        return isColor()
    end
    local function setTextColor(color)
        if tHex[color] == nil then color = parse_color(color) end
        nTextColor = color
        if bVisible then
            updateCursorColor()
        end
    end
    window.setTextColor = setTextColor
    window.setTextColour = setTextColor
    function window.setPaletteColour(colour, r, g, b)
        if tHex[colour] == nil then colour = parse_color(colour) end
        local tCol
        if type(r) == "number" and g == nil and b == nil then
            tCol = { colours.unpackRGB(r) }
            tPalette[colour] = tCol
        else
            if type(r) ~= "number" then expect(2, r, "number") end
            if type(g) ~= "number" then expect(3, g, "number") end
            if type(b) ~= "number" then expect(4, b, "number") end
            tCol = tPalette[colour]
            tCol[1] = r
            tCol[2] = g
            tCol[3] = b
        end
        if bVisible then
            return parent.setPaletteColour(colour, tCol[1], tCol[2], tCol[3])
        end
    end
    window.setPaletteColor = window.setPaletteColour
    function window.getPaletteColour(colour)
        if tHex[colour] == nil then colour = parse_color(colour) end
        local tCol = tPalette[colour]
        return tCol[1], tCol[2], tCol[3]
    end
    window.getPaletteColor = window.getPaletteColour
    local function setBackgroundColor(color)
        if tHex[color] == nil then color = parse_color(color) end
        nBackgroundColor = color
    end
    window.setBackgroundColor = setBackgroundColor
    window.setBackgroundColour = setBackgroundColor
    function window.getSize()
        return nWidth, nHeight
    end
    function window.scroll(n)
        if type(n) ~= "number" then expect(1, n, "number") end
        if n ~= 0 then
            local tNewLines = {}
            local sEmptyText = sEmptySpaceLine
            local sEmptyTextColor = tEmptyColorLines[nTextColor]
            local sEmptyBackgroundColor = tEmptyColorLines[nBackgroundColor]
            for newY = 1, nHeight do
                local y = newY + n
                if y >= 1 and y <= nHeight then
                    tNewLines[newY] = tLines[y]
                else
                    tNewLines[newY] = { sEmptyText, sEmptyTextColor, sEmptyBackgroundColor }
                end
            end
            tLines = tNewLines
            if bVisible then
                redraw()
                updateCursorColor()
                updateCursorPos()
            end
        end
    end
    function window.getTextColor()
        return nTextColor
    end
    function window.getTextColour()
        return nTextColor
    end
    function window.getBackgroundColor()
        return nBackgroundColor
    end
    function window.getBackgroundColour()
        return nBackgroundColor
    end
    function window.getLine(y)
        if type(y) ~= "number" then expect(1, y, "number") end
        if y < 1 or y > nHeight then
            error("Line is out of range.", 2)
        end
        local line = tLines[y]
        return line[1], line[2], line[3]
    end
    function window.setVisible(visible)
        if type(visible) ~= "boolean" then expect(1, visible, "boolean") end
        if bVisible ~= visible then
            bVisible = visible
            if bVisible then
                window.redraw()
            end
        end
    end
    function window.isVisible()
        return bVisible
    end
    function window.redraw()
        if bVisible then
            redraw()
            updatePalette()
            updateCursorBlink()
            updateCursorColor()
            updateCursorPos()
        end
    end
    function window.restoreCursor()
        if bVisible then
            updateCursorBlink()
            updateCursorColor()
            updateCursorPos()
        end
    end
    function window.getPosition()
        return nX, nY
    end
    function window.reposition(new_x, new_y, new_width, new_height, new_parent)
        if type(new_x) ~= "number" then expect(1, new_x, "number") end
        if type(new_y) ~= "number" then expect(2, new_y, "number") end
        if new_width ~= nil or new_height ~= nil then
            expect(3, new_width, "number")
            expect(4, new_height, "number")
        end
        if new_parent ~= nil and type(new_parent) ~= "table" then expect(5, new_parent, "table") end
        nX = new_x
        nY = new_y
        if new_parent then parent = new_parent end
        if new_width and new_height then
            local tNewLines = {}
            createEmptyLines(new_width)
            local sEmptyText = sEmptySpaceLine
            local sEmptyTextColor = tEmptyColorLines[nTextColor]
            local sEmptyBackgroundColor = tEmptyColorLines[nBackgroundColor]
            for y = 1, new_height do
                if y > nHeight then
                    tNewLines[y] = { sEmptyText, sEmptyTextColor, sEmptyBackgroundColor }
                else
                    local tOldLine = tLines[y]
                    if new_width == nWidth then
                        tNewLines[y] = tOldLine
                    elseif new_width < nWidth then
                        tNewLines[y] = {
                            string_sub(tOldLine[1], 1, new_width),
                            string_sub(tOldLine[2], 1, new_width),
                            string_sub(tOldLine[3], 1, new_width),
                        }
                    else
                        tNewLines[y] = {
                            tOldLine[1] .. string_sub(sEmptyText, nWidth + 1, new_width),
                            tOldLine[2] .. string_sub(sEmptyTextColor, nWidth + 1, new_width),
                            tOldLine[3] .. string_sub(sEmptyBackgroundColor, nWidth + 1, new_width),
                        }
                    end
                end
            end
            nWidth = new_width
            nHeight = new_height
            tLines = tNewLines
        end
        if bVisible then
            window.redraw()
        end
    end
    if bVisible then
        window.redraw()
    end
    return window
end