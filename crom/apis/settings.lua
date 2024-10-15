local expect = dofile("crom/modules/main/cc/expect.lua")
local type, expect, field = type, expect.expect, expect.field
local details, values = {}, {}
local function reserialize(value)
    if type(value) ~= "table" then return value end
    return textutils.unserialize(textutils.serialize(value))
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local valid_types = { "number", "string", "boolean", "table" }
for _, v in ipairs(valid_types) do valid_types[v] = true end
function define(name, options)
    expect(1, name, "string")
    expect(2, options, "table", "nil")
    if options then
        options = {
            description = field(options, "description", "string", "nil"),
            default = reserialize(field(options, "default", "number", "string", "boolean", "table", "nil")),
            type = field(options, "type", "string", "nil"),
        }
        if options.type and not valid_types[options.type] then
            error(("Unknown type %q. Expected one of %s."):format(options.type, table.concat(valid_types, ", ")), 2)
        end
    else
        options = {}
    end
    details[name] = options
end
function undefine(name)
    expect(1, name, "string")
    details[name] = nil
end
local function set_value(name, new)
    local old = values[name]
    if old == nil then
        local opt = details[name]
        old = opt and opt.default
    end
    values[name] = new
    if old ~= new then
        os.queueEvent("setting_changed", name, new, old)
    end
end
function set(name, value)
    expect(1, name, "string")
    expect(2, value, "number", "string", "boolean", "table")
    local opt = details[name]
    if opt and opt.type then expect(2, value, opt.type) end
    set_value(name, reserialize(value))
end
function get(name, default)
    expect(1, name, "string")
    local result = values[name]
    if result ~= nil then
        return copy(result)
    elseif default ~= nil then
        return default
    else
        local opt = details[name]
        return opt and copy(opt.default)
    end
end
function getDetails(name)
    expect(1, name, "string")
    local deets = copy(details[name]) or {}
    deets.value = values[name]
    deets.changed = deets.value ~= nil
    if deets.value == nil then deets.value = deets.default end
    return deets
end
function unset(name)
    expect(1, name, "string")
    set_value(name, nil)
end
function clear()
    for name in pairs(values) do
        set_value(name, nil)
    end
end
function getNames()
    local result, n = {}, 1
    for k in pairs(details) do
        result[n], n = k, n + 1
    end
    for k in pairs(values) do
        if not details[k] then result[n], n = k, n + 1 end
    end
    table.sort(result)
    return result
end
function load(sPath)
    expect(1, sPath, "string", "nil")
    local file = fs.open(sPath or ".settings", "r")
    if not file then
        return false
    end
    local sText = file.readAll()
    file.close()
    local tFile = textutils.unserialize(sText)
    if type(tFile) ~= "table" then
        return false
    end
    for k, v in pairs(tFile) do
        local ty_v = type(v)
        if type(k) == "string" and (ty_v == "string" or ty_v == "number" or ty_v == "boolean" or ty_v == "table") then
            local opt = details[k]
            if not opt or not opt.type or ty_v == opt.type then
                local ok, v = pcall(reserialize, v)
                if ok then set_value(k, v) end
            end
        end
    end
    return true
end
function save(sPath)
    expect(1, sPath, "string", "nil")
    local file = fs.open(sPath or ".settings", "w")
    if not file then
        return false
    end
    file.write(textutils.serialize(values))
    file.close()
    return true
end