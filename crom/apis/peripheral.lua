local expect = dofile("crom/modules/main/cc/expect.lua").expect
local native = peripheral
local sides = rs.getSides()
function getNames()
    local results = {}
    for n = 1, #sides do
        local side = sides[n]
        if native.isPresent(side) then
            table.insert(results, side)
            if native.hasType(side, "peripheral_hub") then
                local remote = native.call(side, "getNamesRemote")
                for _, name in ipairs(remote) do
                    table.insert(results, name)
                end
            end
        end
    end
    return results
end
function isPresent(name)
    expect(1, name, "string")
    if native.isPresent(name) then
        return true
    end
    for n = 1, #sides do
        local side = sides[n]
        if native.hasType(side, "peripheral_hub") and native.call(side, "isPresentRemote", name) then
            return true
        end
    end
    return false
end
function getType(peripheral)
    expect(1, peripheral, "string", "table")
    if type(peripheral) == "string" then 
        if native.isPresent(peripheral) then
            return native.getType(peripheral)
        end
        for n = 1, #sides do
            local side = sides[n]
            if native.hasType(side, "peripheral_hub") and native.call(side, "isPresentRemote", peripheral) then
                return native.call(side, "getTypeRemote", peripheral)
            end
        end
        return nil
    else
        local mt = getmetatable(peripheral)
        if not mt or mt.__name ~= "peripheral" or type(mt.types) ~= "table" then
            error("bad argument #1 (table is not a peripheral)", 2)
        end
        return table.unpack(mt.types)
    end
end
function hasType(peripheral, peripheral_type)
    expect(1, peripheral, "string", "table")
    expect(2, peripheral_type, "string")
    if type(peripheral) == "string" then 
        if native.isPresent(peripheral) then
            return native.hasType(peripheral, peripheral_type)
        end
        for n = 1, #sides do
            local side = sides[n]
            if native.hasType(side, "peripheral_hub") and native.call(side, "isPresentRemote", peripheral) then
                return native.call(side, "hasTypeRemote", peripheral, peripheral_type)
            end
        end
        return nil
    else
        local mt = getmetatable(peripheral)
        if not mt or mt.__name ~= "peripheral" or type(mt.types) ~= "table" then
            error("bad argument #1 (table is not a peripheral)", 2)
        end
        return mt.types[peripheral_type] ~= nil
    end
end
function getMethods(name)
    expect(1, name, "string")
    if native.isPresent(name) then
        return native.getMethods(name)
    end
    for n = 1, #sides do
        local side = sides[n]
        if native.hasType(side, "peripheral_hub") and native.call(side, "isPresentRemote", name) then
            return native.call(side, "getMethodsRemote", name)
        end
    end
    return nil
end
function getName(peripheral)
    expect(1, peripheral, "table")
    local mt = getmetatable(peripheral)
    if not mt or mt.__name ~= "peripheral" or type(mt.name) ~= "string" then
        error("bad argument #1 (table is not a peripheral)", 2)
    end
    return mt.name
end
function call(name, method, ...)
    expect(1, name, "string")
    expect(2, method, "string")
    if native.isPresent(name) then
        return native.call(name, method, ...)
    end
    for n = 1, #sides do
        local side = sides[n]
        if native.hasType(side, "peripheral_hub") and native.call(side, "isPresentRemote", name) then
            return native.call(side, "callRemote", name, method, ...)
        end
    end
    return nil
end
function wrap(name)
    expect(1, name, "string")
    local methods = peripheral.getMethods(name)
    if not methods then
        return nil
    end
    local types = { peripheral.getType(name) }
    for i = 1, #types do types[types[i]] = true end
    local result = setmetatable({}, {
        __name = "peripheral",
        name = name,
        type = types[1],
        types = types,
    })
    for _, method in ipairs(methods) do
        result[method] = function(...)
            return peripheral.call(name, method, ...)
        end
    end
    return result
end
function find(ty, filter)
    expect(1, ty, "string")
    expect(2, filter, "function", "nil")
    local results = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, ty) then
            local wrapped = peripheral.wrap(name)
            if filter == nil or filter(name, wrapped) then
                table.insert(results, wrapped)
            end
        end
    end
    return table.unpack(results)
end