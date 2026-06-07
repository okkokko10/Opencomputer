

local debugger = {}

local pretty = require "cc.pretty"

debugger.width = 25

function debugger.run(into)
    local path = shell.resolve(into)
    
    local f = fs.open(path,"w")
    f.write("---------- START --" .. os.date() .. "------\n")
    pcall( function ()
        while true do
            local event,message = os.pullEvent("debug")
            local success, result = pcall(function ()
                print("...")
                local m = pretty.pretty(message)
                pretty.print(m)
                f.write("---\n")
                f.write(pretty.render(m,debugger.width))
            end)
            if not success then
                print("error: ",result)
            end
            if f.seek() > 20*1000 then
                f.close()
                f = fs.open(path,"w")
                f.write("---------- RESTART --" .. os.date() .. "------\n")
            end
        end
    end 
    )
    f.close()
    
end

function debugger.log(message)
    os.queueEvent("debug",message)
end
print(...)
if select(1,...) == "run" then
    debugger.run(select(2,...) or "debug_log.txt")
end

return debugger