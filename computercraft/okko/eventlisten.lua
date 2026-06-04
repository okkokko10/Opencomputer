
local pretty = require "cc.pretty"
while true do 
    local msg = {os.pullEvent()}
    if msg[1] == "monitor_touch" then
        sleep(10)
    end
    local line = {}
    for index, value in ipairs(msg) do 
        line[index] = pretty.pretty(value) 
    
    end; 
    pretty.print(pretty.group(pretty.concat(unpack(line))))
    print("---")
end

