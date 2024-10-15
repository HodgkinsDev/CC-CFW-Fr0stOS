local expect = require "cc.expect".expect
local function choice_impl(text, choices, add_space)
    local results = {}
    for n = 1, #choices do
        local option = choices[n]
        if #option + (add_space and 1 or 0) > #text and option:sub(1, #text) == text then
            local result = option:sub(#text + 1)
            if add_space then
                table.insert(results, result .. " ")
            else
                table.insert(results, result)
            end
        end
    end
    return results
end
local function choice(text, choices, add_space)
    expect(1, text, "string")
    expect(2, choices, "table")
    expect(3, add_space, "boolean", "nil")
    return choice_impl(text, choices, add_space)
end
local function peripheral_(text, add_space)
    expect(1, text, "string")
    expect(2, add_space, "boolean", "nil")
    return choice_impl(text, peripheral.getNames(), add_space)
end
local sides = redstone.getSides()
local function side(text, add_space)
    expect(1, text, "string")
    expect(2, add_space, "boolean", "nil")
    return choice_impl(text, sides, add_space)
end
local function setting(text, add_space)
    expect(1, text, "string")
    expect(2, add_space, "boolean", "nil")
    return choice_impl(text, settings.getNames(), add_space)
end
local command_list
local function command(text, add_space)
    expect(1, text, "string")
    expect(2, add_space, "boolean", "nil")
    if command_list == nil then
        command_list = commands and commands.list() or {}
    end
    return choice_impl(text, command_list, add_space)
end
return {
    choice = choice,
    peripheral = peripheral_,
    side = side,
    setting = setting,
    command = command,
}