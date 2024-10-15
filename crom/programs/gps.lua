local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " host")
    print(programName .. " host <x> <y> <z>")
    print(programName .. " locate")
end
local tArgs = { ... }
if #tArgs < 1 then
    printUsage()
    return
end
 local sCommand = tArgs[1]
if sCommand == "locate" then
    gps.locate(2, true)
elseif sCommand == "host" then
    if pocket then
        print("GPS Hosts must be stationary")
        return
    end
    local sModemSide = nil
    for _, sSide in ipairs(rs.getSides()) do
        if peripheral.getType(sSide) == "modem" and peripheral.call(sSide, "isWireless") then
            sModemSide = sSide
            break
        end
    end
    if sModemSide == nil then
        print("No wireless modems found. 1 required.")
        return
    end
    local x, y, z
    if #tArgs >= 4 then
        x = tonumber(tArgs[2])
        y = tonumber(tArgs[3])
        z = tonumber(tArgs[4])
        if x == nil or y == nil or z == nil then
            printUsage()
            return
        end
        print("Position is " .. x .. "," .. y .. "," .. z)
    else
        x, y, z = gps.locate(2, true)
        if x == nil then
            print("Run \"gps host <x> <y> <z>\" to set position manually")
            return
        end
    end
    local modem = peripheral.wrap(sModemSide)
    print("Opening channel on modem " .. sModemSide)
    modem.open(gps.CHANNEL_GPS)
    local nServed = 0
    while true do
        local e, p1, p2, p3, p4, p5 = os.pullEvent("modem_message")
        if e == "modem_message" then
            local sSide, sChannel, sReplyChannel, sMessage, nDistance = p1, p2, p3, p4, p5
            if sSide == sModemSide and sChannel == gps.CHANNEL_GPS and sMessage == "PING" and nDistance then
                modem.transmit(sReplyChannel, gps.CHANNEL_GPS, { x, y, z })
                nServed = nServed + 1
                if nServed > 1 then
                    local _, y = term.getCursorPos()
                    term.setCursorPos(1, y - 1)
                end
                print(nServed .. " GPS requests served")
            end
        end
    end
else
    printUsage()
end