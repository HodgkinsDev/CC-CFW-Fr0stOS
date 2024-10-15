if _HOST:find("UnBIOS") then return end

local args = { ... }  -- Collect command-line arguments

-- Ensure only one argument is provided, otherwise exit
if #args ~= 1 then
    return
end

local biosPath = args[1]  -- First and only argument is the BIOS path

local keptAPIs = {bit32 = true, bit = true, ccemux = true, config = true, coroutine = true, debug = true, fs = true, http = true, mounter = true, os = true, periphemu = true, peripheral = true, redstone = true, rs = true, term = true, utf8 = true, _HOST = true, _CC_DEFAULT_SETTINGS = true, _CC_DISABLE_LUA51_FEATURES = true, _VERSION = true, assert = true, collectgarbage = true, error = true, gcinfo = true, getfenv = true, getmetatable = true, ipairs = true, __inext = true, load = true, loadstring = true, math = true, newproxy = true, next = true, pairs = true, pcall = true, rawequal = true, rawget = true, rawlen = true, rawset = true, select = true, setfenv = true, setmetatable = true, string = true, table = true, tonumber = true, tostring = true, type = true, unpack = true, xpcall = true, turtle = true, pocket = true, commands = true, _G = true}
local t = {}
for k in pairs(_G) do if not keptAPIs[k] then table.insert(t, k) end end
for _,k in ipairs(t) do _G[k] = nil end
local native = _G.term.native()
for _, method in ipairs {"nativePaletteColor", "nativePaletteColour", "screenshot"} do native[method] = _G.term[method] end
_G.term = native
_G.http.checkURL = _G.http.checkURLAsync
_G.http.websocket = _G.http.websocketAsync
if _G.commands then _G.commands = _G.commands.native end
if _G.turtle then _G.turtle.native, _G.turtle.craft = nil end

local delete = {os = {"version", "pullEventRaw", "pullEvent", "run", "loadAPI", "unloadAPI", "sleep"}, http = {"get", "post", "put", "delete", "patch", "options", "head", "trace", "listen", "checkURLAsync", "websocketAsync"}, fs = {"complete", "isDriveRoot"}}
for k,v in pairs(delete) do for _,a in ipairs(v) do _G[k][a] = nil end end
_G._HOST = _G._HOST .. " (UnBIOS)"

local olderror = error
_G.error = function() end
_G.term.redirect = function() end

function _G.term.native()
    _G.term.native = nil
    _G.term.redirect = nil
    _G.error = olderror
    term.setBackgroundColor(32768)
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    term.clear()
    
    -- Use the biosPath argument instead of a predefined path
    local file = fs.open(biosPath, "r")
    if file == nil then
        term.setCursorBlink(false)
        term.setTextColor(16384)
        term.write("Could not find " .. biosPath .. ". UnBIOS cannot continue.")
        term.setCursorPos(1, 2)
        term.write("Press any key to continue")
        coroutine.yield("key")
        os.shutdown()
    end
    
    local fn, err = loadstring(file.readAll(), "@bios.lua")
    file.close()
    if fn == nil then
        term.setCursorBlink(false)
        term.setTextColor(16384)
        term.write("Could not load " .. biosPath .. ". UnBIOS cannot continue.")
        term.setCursorPos(1, 2)
        term.write(err)
        term.setCursorPos(1, 3)
        term.write("Press any key to continue")
        coroutine.yield("key")
        os.shutdown()
    end
    
    setfenv(fn, _G)
    local oldshutdown = os.shutdown
    os.shutdown = function()
        os.shutdown = oldshutdown
        return fn()
    end
end

if debug then
    local function restoreValue(tab, idx, name, hint)
        local i, key, value = 1, debug.getupvalue(tab[idx], hint)
        while key ~= name and key ~= nil do
            key, value = debug.getupvalue(tab[idx], i)
            i=i+1
        end
        tab[idx] = value or tab[idx]
    end
    restoreValue(_G, "loadstring", "nativeloadstring", 1)
    restoreValue(_G, "load", "nativeload", 5)
    restoreValue(http, "request", "nativeHTTPRequest", 3)
    restoreValue(os, "shutdown", "nativeShutdown", 1)
    restoreValue(os, "reboot", "nativeReboot", 1)
    if turtle then
        restoreValue(turtle, "equipLeft", "v", 1)
        restoreValue(turtle, "equipRight", "v", 1)
    end
    do
        local i, key, value = 1, debug.getupvalue(peripheral.isPresent, 2)
        while key ~= "native" and key ~= nil do
            key, value = debug.getupvalue(peripheral.isPresent, i)
            i=i+1
        end
        _G.peripheral = value or peripheral
    end
end
coroutine.yield()
