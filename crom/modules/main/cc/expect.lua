local native_select, native_type = select, type
local function get_type_names(...)
    local types = table.pack(...)
    for i = types.n, 1, -1 do
        if types[i] == "nil" then table.remove(types, i) end
    end
    if #types <= 1 then
        return tostring(...)
    else
        return table.concat(types, ", ", 1, #types - 1) .. " or " .. types[#types]
    end
end
local function get_display_type(value, t)
    if t ~= "table" and t ~= "userdata" then return t end
    local metatable = debug.getmetatable(value)
    if not metatable then return t end
    local name = rawget(metatable, "__name")
    if type(name) == "string" then return name else return t end
end
local function expect(index, value, ...)
    local t = native_type(value)
    for i = 1, native_select("#", ...) do
        if t == native_select(i, ...) then return value end
    end
    local name
    local ok, info = pcall(debug.getinfo, 3, "nS")
    if ok and info.name and info.name ~= "" and info.what ~= "C" then name = info.name end
    t = get_display_type(value, t)
    local type_names = get_type_names(...)
    if name then
        error(("bad argument #%d to '%s' (%s expected, got %s)"):format(index, name, type_names, t), 3)
    else
        error(("bad argument #%d (%s expected, got %s)"):format(index, type_names, t), 3)
    end
end
local function field(tbl, index, ...)
    expect(1, tbl, "table")
    expect(2, index, "string")
    local value = tbl[index]
    local t = native_type(value)
    for i = 1, native_select("#", ...) do
        if t == native_select(i, ...) then return value end
    end
    t = get_display_type(value, t)
    if value == nil then
        error(("field '%s' missing from table"):format(index), 3)
    else
        error(("bad field '%s' (%s expected, got %s)"):format(index, get_type_names(...), t), 3)
    end
end
local function is_nan(num)
  return num ~= num
end
local function range(num, min, max)
  expect(1, num, "number")
  min = expect(2, min, "number", "nil") or -math.huge
  max = expect(3, max, "number", "nil") or math.huge
  if min > max then
      error("min must be less than or equal to max)", 2)
  end
  if is_nan(num) or num < min or num > max then
      error(("number outside of range (expected %s to be within %s and %s)"):format(num, min, max), 3)
  end
  return num
end
return setmetatable({
    expect = expect,
    field = field,
    range = range,
}, { __call = function(_, ...) return expect(...) end })