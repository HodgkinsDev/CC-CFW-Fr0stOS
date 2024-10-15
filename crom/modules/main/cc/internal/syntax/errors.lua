local pretty = require "cc.pretty"
local expect = require "cc.expect".expect
local tokens = require "cc.internal.syntax.parser".tokens
local function annotate(start_pos, end_pos, msg)
    if msg == nil and (type(end_pos) == "string" or type(end_pos) == "table" or type(end_pos) == "nil") then
        end_pos, msg = start_pos, end_pos
    end
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, msg, "string", "table", "nil")
    return { tag = "annotate", start_pos = start_pos, end_pos = end_pos, msg = msg or "" }
end
local function code(msg) return pretty.text(msg, colours.lightGrey) end
local token_names = setmetatable({
    [tokens.IDENT] = "identifier",
    [tokens.NUMBER] = "number",
    [tokens.STRING] = "string",
    [tokens.EOF] = "end of file",
    [tokens.ADD] = code("+"),
    [tokens.AND] = code("and"),
    [tokens.BREAK] = code("break"),
    [tokens.CBRACE] = code("}"),
    [tokens.COLON] = code(":"),
    [tokens.COMMA] = code(","),
    [tokens.CONCAT] = code(".."),
    [tokens.CPAREN] = code(")"),
    [tokens.CSQUARE] = code("]"),
    [tokens.DIV] = code("/"),
    [tokens.DO] = code("do"),
    [tokens.DOT] = code("."),
    [tokens.DOTS] = code("..."),
    [tokens.DOUBLE_COLON] = code("::"),
    [tokens.ELSE] = code("else"),
    [tokens.ELSEIF] = code("elseif"),
    [tokens.END] = code("end"),
    [tokens.EQ] = code("=="),
    [tokens.EQUALS] = code("="),
    [tokens.FALSE] = code("false"),
    [tokens.FOR] = code("for"),
    [tokens.FUNCTION] = code("function"),
    [tokens.GE] = code(">="),
    [tokens.GOTO] = code("goto"),
    [tokens.GT] = code(">"),
    [tokens.IF] = code("if"),
    [tokens.IN] = code("in"),
    [tokens.LE] = code("<="),
    [tokens.LEN] = code("#"),
    [tokens.LOCAL] = code("local"),
    [tokens.LT] = code("<"),
    [tokens.MOD] = code("%"),
    [tokens.MUL] = code("*"),
    [tokens.NE] = code("~="),
    [tokens.NIL] = code("nil"),
    [tokens.NOT] = code("not"),
    [tokens.OBRACE] = code("{"),
    [tokens.OPAREN] = code("("),
    [tokens.OR] = code("or"),
    [tokens.OSQUARE] = code("["),
    [tokens.POW] = code("^"),
    [tokens.REPEAT] = code("repeat"),
    [tokens.RETURN] = code("return"),
    [tokens.SEMICOLON] = code(";"),
    [tokens.SUB] = code("-"),
    [tokens.THEN] = code("then"),
    [tokens.TRUE] = code("true"),
    [tokens.UNTIL] = code("until"),
    [tokens.WHILE] = code("while"),
}, { __index = function(_, name) error("No such token " .. tostring(name), 2) end })
local errors = {}
function errors.unfinished_string(start_pos, end_pos, quote)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, quote, "string")
    return {
        "This string is not finished. Are you missing a closing quote (" .. code(quote) .. ")?",
        annotate(start_pos, "String started here."),
        annotate(end_pos, "Expected a closing quote here."),
    }
end
function errors.unfinished_string_escape(start_pos, end_pos, quote)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, quote, "string")
    return {
        "This string is not finished.",
        annotate(start_pos, "String started here."),
        annotate(end_pos, "An escape sequence was started here, but with nothing following it."),
    }
end
function errors.unfinished_long_string(start_pos, end_pos, len)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, len, "number")
    return {
        "This string was never finished.",
        annotate(start_pos, end_pos, "String was started here."),
        "We expected a closing delimiter (" .. code("]" .. ("="):rep(len - 1) .. "]") .. ") somewhere after this string was started.",
    }
end
function errors.malformed_long_string(start_pos, end_pos, len)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, len, "number")
    return {
        "Incorrect start of a long string.",
        annotate(start_pos, end_pos),
        "Tip: If you wanted to start a long string here, add an extra " .. code("[") .. " here.",
    }
end
function errors.nested_long_str(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        code("[[") .. " cannot be nested inside another " .. code("[[ ... ]]"),
        annotate(start_pos, end_pos),
    }
end
function errors.malformed_number(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "This isn't a valid number.",
        annotate(start_pos, end_pos),
        "Numbers must be in one of the following formats: " .. code("123") .. ", "
        .. code("3.14") .. ", " .. code("23e35") .. ", " .. code("0x01AF") .. ".",
    }
end
function errors.unfinished_long_comment(start_pos, end_pos, len)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    expect(3, len, "number")
    return {
        "This comment was never finished.",
        annotate(start_pos, end_pos, "Comment was started here."),
        "We expected a closing delimiter (" .. code("]" .. ("="):rep(len - 1) .. "]") .. ") somewhere after this comment was started.",
    }
end
function errors.wrong_and(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "Unexpected character.",
        annotate(start_pos, end_pos),
        "Tip: Replace this with " .. code("and") .. " to check if both values are true.",
    }
end
function errors.wrong_or(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "Unexpected character.",
        annotate(start_pos, end_pos),
        "Tip: Replace this with " .. code("or") .. " to check if either value is true.",
    }
end
function errors.wrong_ne(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "Unexpected character.",
        annotate(start_pos, end_pos),
        "Tip: Replace this with " .. code("~=") .. " to check if two values are not equal.",
    }
end
function errors.unexpected_character(pos)
    expect(1, pos, "number")
    return {
        "Unexpected character.",
        annotate(pos, "This character isn't usable in Lua code."),
    }
end
function errors.expected_expression(token, start_pos, end_pos)
    expect(1, token, "number")
    expect(2, start_pos, "number")
    expect(3, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ". Expected an expression.",
        annotate(start_pos, end_pos),
    }
end
function errors.expected_var(token, start_pos, end_pos)
    expect(1, token, "number")
    expect(2, start_pos, "number")
    expect(3, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ". Expected a variable name.",
        annotate(start_pos, end_pos),
    }
end
function errors.use_double_equals(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "Unexpected " .. code("=") .. " in expression.",
        annotate(start_pos, end_pos),
        "Tip: Replace this with " .. code("==") .. " to check if two values are equal.",
    }
end
function errors.table_key_equals(start_pos, end_pos)
    expect(1, start_pos, "number")
    expect(2, end_pos, "number")
    return {
        "Unexpected " .. code("=") .. " in expression.",
        annotate(start_pos, end_pos),
        "Tip: Wrap the preceding expression in " .. code("[") .. " and " .. code("]") .. " to use it as a table key.",
    }
end
function errors.missing_table_comma(token, token_start, token_end, prev)
    expect(1, token, "number")
    expect(2, token_start, "number")
    expect(3, token_end, "number")
    expect(4, prev, "number")
    return {
        "Unexpected " .. token_names[token] .. " in table.",
        annotate(token_start, token_end),
        annotate(prev + 1, prev + 1, "Are you missing a comma here?"),
    }
end
function errors.trailing_call_comma(comma_start, comma_end, paren_start, paren_end)
    expect(1, comma_start, "number")
    expect(2, comma_end, "number")
    expect(3, paren_start, "number")
    expect(4, paren_end, "number")
    return {
        "Unexpected " .. code(")") .. " in function call.",
        annotate(paren_start, paren_end),
        annotate(comma_start, comma_end, "Tip: Try removing this " .. code(",") .. "."),
    }
end
function errors.expected_statement(token, start_pos, end_pos)
    expect(1, token, "number")
    expect(2, start_pos, "number")
    expect(3, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ". Expected a statement.",
        annotate(start_pos, end_pos),
    }
end
function errors.local_function_dot(local_start, local_end, dot_start, dot_end)
    expect(1, local_start, "number")
    expect(2, local_end, "number")
    expect(3, dot_start, "number")
    expect(4, dot_end, "number")
    return {
        "Cannot use " .. code("local function") .. " with a table key.",
        annotate(dot_start, dot_end, code(".") .. " appears here."),
        annotate(local_start, local_end, "Tip: " .. "Try removing this " .. code("local") .. " keyword."),
    }
end
function errors.standalone_name(token, pos)
    expect(1, token, "number")
    expect(2, pos, "number")
    return {
        "Unexpected " .. token_names[token] .. " after name.",
        annotate(pos),
        "Did you mean to assign this or call it as a function?",
    }
end
function errors.standalone_names(token, pos)
    expect(1, token, "number")
    expect(2, pos, "number")
    return {
        "Unexpected " .. token_names[token] .. " after name.",
        annotate(pos),
        "Did you mean to assign this?",
    }
end
function errors.standalone_name_call(token, pos)
    expect(1, token, "number")
    expect(2, pos, "number")
    return {
        "Unexpected " .. token_names[token] .. " after name.",
        annotate(pos + 1, "Expected something before the end of the line."),
        "Tip: Use " .. code("()") .. " to call with no arguments.",
    }
end
function errors.expected_then(if_start, if_end, token_pos)
    expect(1, if_start, "number")
    expect(2, if_end, "number")
    expect(3, token_pos, "number")
    return {
        "Expected " .. code("then") .. " after if condition.",
        annotate(if_start, if_end, "If statement started here."),
        annotate(token_pos, "Expected " .. code("then") .. " before here."),
    }
end
function errors.expected_end(block_start, block_end, token, token_start, token_end)
    return {
        "Unexpected " .. token_names[token] .. ". Expected " .. code("end") .. " or another statement.",
        annotate(block_start, block_end, "Block started here."),
        annotate(token_start, token_end, "Expected end of block here."),
    }
end
function errors.unexpected_end(start_pos, end_pos)
    return {
        "Unexpected " .. code("end") .. ".",
        annotate(start_pos, end_pos),
        "Your program contains more " .. code("end") .. "s than needed. Check " ..
        "each block (" .. code("if") .. ", " .. code("for") .. ", " ..
        code("function") .. ", ...) only has one " .. code("end") .. ".",
    }
end
function errors.unclosed_label(open_start, open_end, token, start_pos, end_pos)
    expect(1, open_start, "number")
    expect(2, open_end, "number")
    expect(3, token, "number")
    expect(4, start_pos, "number")
    expect(5, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ".",
        annotate(open_start, open_end, "Label was started here."),
        annotate(start_pos, end_pos, "Tip: Try adding " .. code("::") .. " here."),
    }
end
function errors.unexpected_token(token, start_pos, end_pos)
    expect(1, token, "number")
    expect(2, start_pos, "number")
    expect(3, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ".",
        annotate(start_pos, end_pos),
    }
end
function errors.unclosed_brackets(open_start, open_end, token, start_pos, end_pos)
    expect(1, open_start, "number")
    expect(2, open_end, "number")
    expect(3, token, "number")
    expect(4, start_pos, "number")
    expect(5, end_pos, "number")
    return {
        "Unexpected " .. token_names[token] .. ". Are you missing a closing bracket?",
        annotate(open_start, open_end, "Brackets were opened here."),
        annotate(start_pos, end_pos, "Unexpected " .. token_names[token] .. " here."),
    }
end
function errors.expected_function_args(token, start_pos, end_pos)
    return {
        "Unexpected " .. token_names[token] .. ". Expected " .. code("(") .. " to start function arguments.",
        annotate(start_pos, end_pos),
    }
end
return errors