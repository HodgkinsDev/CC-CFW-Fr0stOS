local expect = dofile("crom/modules/main/cc/expect.lua").expect
CHANNEL_BROADCAST = 65535
CHANNEL_REPEAT = 65533
MAX_ID_CHANNELS = 65500
local received_messages = {}
local hostnames = {}
local prune_received_timer
local function id_as_channel(id)
    return (id or os.getComputerID()) % MAX_ID_CHANNELS
end
function open(modem)
    expect(1, modem, "string")
    if peripheral.getType(modem) ~= "modem" then
        error("No such modem: " .. modem, 2)
    end
    peripheral.call(modem, "open", id_as_channel())
    peripheral.call(modem, "open", CHANNEL_BROADCAST)
end
function close(modem)
    expect(1, modem, "string", "nil")
    if modem then
        if peripheral.getType(modem) ~= "modem" then
            error("No such modem: " .. modem, 2)
        end
        peripheral.call(modem, "close", id_as_channel())
        peripheral.call(modem, "close", CHANNEL_BROADCAST)
    else
        for _, modem in ipairs(peripheral.getNames()) do
            if isOpen(modem) then
                close(modem)
            end
        end
    end
end
function isOpen(modem)
    expect(1, modem, "string", "nil")
    if modem then
        if peripheral.getType(modem) == "modem" then
            return peripheral.call(modem, "isOpen", id_as_channel()) and peripheral.call(modem, "isOpen", CHANNEL_BROADCAST)
        end
    else
        for _, modem in ipairs(peripheral.getNames()) do
            if isOpen(modem) then
                return true
            end
        end
    end
    return false
end
function send(recipient, message, protocol)
    expect(1, recipient, "number")
    expect(3, protocol, "string", "nil")
    local message_id = math.random(1, 2147483647)
    received_messages[message_id] = os.clock() + 9.5
    if not prune_received_timer then prune_received_timer = os.startTimer(10) end
    local reply_channel = id_as_channel()
    local message_wrapper = {
        nMessageID = message_id,
        nRecipient = recipient,
        nSender = os.getComputerID(),
        message = message,
        sProtocol = protocol,
    }
    local sent = false
    if recipient == os.getComputerID() then
        os.queueEvent("rednet_message", os.getComputerID(), message, protocol)
        sent = true
    else
        if recipient ~= CHANNEL_BROADCAST then
            recipient = id_as_channel(recipient)
        end
        for _, modem in ipairs(peripheral.getNames()) do
            if isOpen(modem) then
                peripheral.call(modem, "transmit", recipient, reply_channel, message_wrapper)
                peripheral.call(modem, "transmit", CHANNEL_REPEAT, reply_channel, message_wrapper)
                sent = true
            end
        end
    end
    return sent
end
function broadcast(message, protocol)
    expect(2, protocol, "string", "nil")
    send(CHANNEL_BROADCAST, message, protocol)
end
function receive(protocol_filter, timeout)
    if type(protocol_filter) == "number" and timeout == nil then
        protocol_filter, timeout = nil, protocol_filter
    end
    expect(1, protocol_filter, "string", "nil")
    expect(2, timeout, "number", "nil")
    local timer = nil
    local event_filter = nil
    if timeout then
        timer = os.startTimer(timeout)
        event_filter = nil
    else
        event_filter = "rednet_message"
    end
    while true do
        local event, p1, p2, p3 = os.pullEvent(event_filter)
        if event == "rednet_message" then
            local sender_id, message, protocol = p1, p2, p3
            if protocol_filter == nil or protocol == protocol_filter then
                return sender_id, message, protocol
            end
        elseif event == "timer" then
            if p1 == timer then
                return nil
            end
        end
    end
end
function host(protocol, hostname)
    expect(1, protocol, "string")
    expect(2, hostname, "string")
    if hostname == "localhost" then
        error("Reserved hostname", 2)
    end
    if hostnames[protocol] ~= hostname then
        if lookup(protocol, hostname) ~= nil then
            error("Hostname in use", 2)
        end
        hostnames[protocol] = hostname
    end
end
function unhost(protocol)
    expect(1, protocol, "string")
    hostnames[protocol] = nil
end
function lookup(protocol, hostname)
    expect(1, protocol, "string")
    expect(2, hostname, "string", "nil")
    local results = nil
    if hostname == nil then
        results = {}
    end
    if hostnames[protocol] then
        if hostname == nil then
            table.insert(results, os.getComputerID())
        elseif hostname == "localhost" or hostname == hostnames[protocol] then
            return os.getComputerID()
        end
    end
    if not isOpen() then
        if results then
            return table.unpack(results)
        end
        return nil
    end
    broadcast({
        sType = "lookup",
        sProtocol = protocol,
        sHostname = hostname,
    }, "dns")
    local timer = os.startTimer(2)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local sender_id, message, message_protocol = p1, p2, p3
            if message_protocol == "dns" and type(message) == "table" and message.sType == "lookup response" then
                if message.sProtocol == protocol then
                    if hostname == nil then
                        table.insert(results, sender_id)
                    elseif message.sHostname == hostname then
                        return sender_id
                    end
                end
            end
        elseif event == "timer" and p1 == timer then
            break
        end
    end
    if results then
        return table.unpack(results)
    end
    return nil
end
local started = false
function run()
    if started then
        error("rednet is already running", 2)
    end
    started = true
    while true do
        local event, p1, p2, p3, p4 = os.pullEventRaw()
        if event == "modem_message" then
            local modem, channel, reply_channel, message = p1, p2, p3, p4
            if channel == id_as_channel() or channel == CHANNEL_BROADCAST then
                if type(message) == "table" and type(message.nMessageID) == "number"
                    and message.nMessageID == message.nMessageID and not received_messages[message.nMessageID]
                    and (type(message.nSender) == "nil" or (type(message.nSender) == "number" and message.nSender == message.nSender))
                    and ((message.nRecipient and message.nRecipient == os.getComputerID()) or channel == CHANNEL_BROADCAST)
                    and isOpen(modem)
                then
                    received_messages[message.nMessageID] = os.clock() + 9.5
                    if not prune_received_timer then prune_received_timer = os.startTimer(10) end
                    os.queueEvent("rednet_message", message.nSender or reply_channel, message.message, message.sProtocol)
                end
            end
        elseif event == "rednet_message" then
            local sender, message, protocol = p1, p2, p3
            if protocol == "dns" and type(message) == "table" and message.sType == "lookup" then
                local hostname = hostnames[message.sProtocol]
                if hostname ~= nil and (message.sHostname == nil or message.sHostname == hostname) then
                    send(sender, {
                        sType = "lookup response",
                        sHostname = hostname,
                        sProtocol = message.sProtocol,
                    }, "dns")
                end
            end
        elseif event == "timer" and p1 == prune_received_timer then
            prune_received_timer = nil
            local now, has_more = os.clock(), nil
            for message_id, deadline in pairs(received_messages) do
                if deadline <= now then received_messages[message_id] = nil
                else has_more = true end
            end
            prune_received_timer = has_more and os.startTimer(10)
        end
    end
end