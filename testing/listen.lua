
local event = require "event"
local component = require "component"
local shell = require "shell"
local modem = component.modem

local ser = require("serialization").serialize
local function serprint(t) print(ser(t)) end


local function read_message(name,localAddress, remoteAddress, port, distance, ...)
    print("local: " .. localAddress .. " remote: " .. remoteAddress .. " port: " .. port .. " distance: " .. distance)
    print(...)
    if select(1,...) == "execute" then
        print("executing")
        shell.execute(select(2,...))
    end
end
local function loop()
    
    modem.open(1)
    while true do
        local msg = {event.pull(1,"modem_message")}
        -- serprint(msg)
        if msg ~= nil and msg[1] ~= nil then
            read_message(table.unpack(msg))
        end
    end
end

loop()


