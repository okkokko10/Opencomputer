
local pretty = require "cc.pretty"

local timers = 0

while true do 
    local msg = {os.pullEvent()}
    if msg[1] == "monitor_touch" then
        sleep(10)
    end
    if msg[1] == "timer" then
        timers = timers + 1
    else
        if timers > 0 then
            print("(timers: " .. timers .. ")")
            timers = 0
        end
        local line = {}
        for index, value in ipairs(msg) do 
            line[index] = pretty.pretty(value)
        
        end; 
        pretty.print(pretty.group(pretty.concat(unpack(line))))
        print("---")
    end
end

