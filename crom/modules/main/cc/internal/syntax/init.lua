local expect = require "cc.expect".expect
local lex_one = require "cc.internal.syntax.lexer".lex_one
local parser = require "cc.internal.syntax.parser"
local error_printer = require "cc.internal.error_printer"
local error_sentinel = {}
local function make_context(input)
    expect(1, input, "string")
    local context = {}
    local lines = { 1 }
    function context.line(pos) lines[#lines + 1] = pos end
    function context.get_pos(pos)
        expect(1, pos, "number")
        for i = #lines, 1, -1 do
            local start = lines[i]
            if pos >= start then return i, pos - start + 1 end
        end
        error("Position is <= 0", 2)
    end
    function context.get_line(pos)
        expect(1, pos, "number")
        for i = #lines, 1, -1 do
            local start = lines[i]
            if pos >= start then return input:match("[^\r\n]*", start) end
        end
        error("Position is <= 0", 2)
    end
    return context
end
local function make_lexer(input, context)
    local tokens, last_token = parser.tokens, parser.tokens.COMMENT
    local pos = 1
    return function()
        while true do
            local token, start, finish = lex_one(context, input, pos)
            if not token then return tokens.EOF, #input + 1, #input + 1 end
            pos = finish + 1
            if token < last_token then
                return token, start, finish
            elseif token == tokens.ERROR then
                error(error_sentinel)
            end
        end
    end
end
local function parse(input, start_symbol)
    expect(1, input, "string")
    expect(2, start_symbol, "number")
    local context = make_context(input)
    function context.report(msg, ...)
        expect(1, msg, "table", "function")
        if type(msg) == "function" then msg = msg(...) end
        error_printer(context, msg)
        error(error_sentinel)
    end
    local ok, err = pcall(parser.parse, context, make_lexer(input, context), start_symbol)
    if ok then
        return true
    elseif err == error_sentinel then
        return false
    else
        error(err, 0)
    end
end
local function parse_program(input) return parse(input, parser.program) end
local function parse_repl(input)
    expect(1, input, "string")
    local context = make_context(input)
    local last_error = nil
    function context.report(msg, ...)
        expect(1, msg, "table", "function")
        if type(msg) == "function" then msg = msg(...) end
        last_error = msg
        error(error_sentinel)
    end
    local lexer = make_lexer(input, context)
    local parsers = {}
    for i, start_code in ipairs { parser.repl_exprs, parser.program } do
        parsers[i] = coroutine.create(parser.parse)
        assert(coroutine.resume(parsers[i], context, coroutine.yield, start_code))
    end
    local ok, err = pcall(function()
        local parsers_n = #parsers
        while true do
            local token, start, finish = lexer()
            local all_failed = true
            for i = 1, parsers_n do
                local parser = parsers[i]
                if parser then
                    local ok, err = coroutine.resume(parser, token, start, finish)
                    if ok then
                        if coroutine.status(parser) == "dead" then return end
                        all_failed = false 
                    elseif err ~= error_sentinel then
                        error(err, 0)
                    else
                        parsers[i] = false
                    end
                end
            end
            if all_failed then error(error_sentinel) end
        end
    end)
    if ok then
        return true
    elseif err == error_sentinel then
        error_printer(context, last_error)
        return false
    else
        error(err, 0)
    end
end
return {
    parse_program = parse_program,
    parse_repl = parse_repl,
}