local expect = dofile("crom/modules/main/cc/expect.lua").expect
local native = term.native and term.native() or term
local redirectTarget = native
local function wrap(_sFunction)
    return function(...)
        return redirectTarget[_sFunction](...)
    end
end
local term = _ENV
term.redirect = function(target)
    expect(1, target, "table")
    if target == term or target == _G.term then
        error("term is not a recommended redirect target, try term.current() instead", 2)
    end
    for k, v in pairs(native) do
        if type(k) == "string" and type(v) == "function" then
            if type(target[k]) ~= "function" then
                target[k] = function()
                    error("Redirect object is missing method " .. k .. ".", 2)
                end
            end
        end
    end
    local oldRedirectTarget = redirectTarget
    redirectTarget = target
    return oldRedirectTarget
end
term.current = function()
    return redirectTarget
end
term.native = function()
    return native
end
for _, method in ipairs { "nativePaletteColor", "nativePaletteColour" } do
    term[method] = native[method]
    native[method] = nil
end
for k, v in pairs(native) do
    if type(k) == "string" and type(v) == "function" and rawget(term, k) == nil then
        term[k] = wrap(k)
    end
end