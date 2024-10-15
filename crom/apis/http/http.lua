local expect = dofile("crom/modules/main/cc/expect.lua").expect
local native = http
local nativeHTTPRequest = http.request
local methods = {
    GET = true, POST = true, HEAD = true,
    OPTIONS = true, PUT = true, DELETE = true,
    PATCH = true, TRACE = true,
}
local function check_key(options, key, ty, opt)
    local value = options[key]
    local valueTy = type(value)
    if (value ~= nil or not opt) and valueTy ~= ty then
        error(("bad field '%s' (%s expected, got %s"):format(key, ty, valueTy), 4)
    end
end
local function check_request_options(options, body)
    check_key(options, "url", "string")
    if body == false then
        check_key(options, "body", "nil")
    else
        check_key(options, "body", "string", not body)
    end
    check_key(options, "headers", "table", true)
    check_key(options, "method", "string", true)
    check_key(options, "redirect", "boolean", true)
    check_key(options, "timeout", "number", true)
    if options.method and not methods[options.method] then
        error("Unsupported HTTP method", 3)
    end
end
local function wrap_request(_url, ...)
    local ok, err = nativeHTTPRequest(...)
    if ok then
        while true do
            local event, param1, param2, param3 = os.pullEvent()
            if event == "http_success" and param1 == _url then
                return param2
            elseif event == "http_failure" and param1 == _url then
                return nil, param2, param3
            end
        end
    end
    return nil, err
end
function get(_url, _headers, _binary)
    if type(_url) == "table" then
        check_request_options(_url, false)
        return wrap_request(_url.url, _url)
    end
    expect(1, _url, "string")
    expect(2, _headers, "table", "nil")
    expect(3, _binary, "boolean", "nil")
    return wrap_request(_url, _url, nil, _headers, _binary)
end
function post(_url, _post, _headers, _binary)
    if type(_url) == "table" then
        check_request_options(_url, true)
        return wrap_request(_url.url, _url)
    end
    expect(1, _url, "string")
    expect(2, _post, "string")
    expect(3, _headers, "table", "nil")
    expect(4, _binary, "boolean", "nil")
    return wrap_request(_url, _url, _post, _headers, _binary)
end
function request(_url, _post, _headers, _binary)
    local url
    if type(_url) == "table" then
        check_request_options(_url)
        url = _url.url
    else
        expect(1, _url, "string")
        expect(2, _post, "string", "nil")
        expect(3, _headers, "table", "nil")
        expect(4, _binary, "boolean", "nil")
        url = _url
    end
    local ok, err = nativeHTTPRequest(_url, _post, _headers, _binary)
    if not ok then
        os.queueEvent("http_failure", url, err)
    end
    return ok, err
end
local nativeCheckURL = native.checkURL
checkURLAsync = nativeCheckURL
function checkURL(_url)
    expect(1, _url, "string")
    local ok, err = nativeCheckURL(_url)
    if not ok then return ok, err end
    while true do
        local _, url, ok, err = os.pullEvent("http_check")
        if url == _url then return ok, err end
    end
end
local nativeWebsocket = native.websocket
local function check_websocket_options(options, body)
    check_key(options, "url", "string")
    check_key(options, "headers", "table", true)
    check_key(options, "timeout", "number", true)
end
function websocketAsync(url, headers)
    local actual_url
    if type(url) == "table" then
        check_websocket_options(url)
        actual_url = url.url
    else
        expect(1, url, "string")
        expect(2, headers, "table", "nil")
        actual_url = url
    end
    local ok, err = nativeWebsocket(url, headers)
    if not ok then
        os.queueEvent("websocket_failure", actual_url, err)
    end
    return ok, err
end
function websocket(url, headers)
    local actual_url
    if type(url) == "table" then
        check_websocket_options(url)
        actual_url = url.url
    else
        expect(1, url, "string")
        expect(2, headers, "table", "nil")
        actual_url = url
    end
    local ok, err = nativeWebsocket(url, headers)
    if not ok then return ok, err end
    while true do
        local event, url, param = os.pullEvent( )
        if event == "websocket_success" and url == actual_url then
            return param
        elseif event == "websocket_failure" and url == actual_url then
            return false, param
        end
    end
end