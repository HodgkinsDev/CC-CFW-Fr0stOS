local function discard_char()
    local timer = os.startTimer(0)
    while true do
        local event, id = os.pullEvent()
        if event == "timer" and id == timer then break
        elseif event == "char" or event == "key" or event == "key_up" then
            os.cancelTimer(timer)
            break
        end
    end
end
return { discard_char = discard_char }