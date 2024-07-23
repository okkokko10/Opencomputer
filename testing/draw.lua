local event = require "event"
local component = require "component"
local shell = require "shell"
local gpu = component.gpu

local ser = require("serialization").serialize
local function serprint(t) print(ser(t)) end

while true do
    local ev = {event.pull()}
    if ev and ev[1] and (ev[1] == "touch" or ev[1] == "drag" or ev[1] == "drop") then
        -- serprint(ev)
        local _,_,x,y,button,playername = table.unpack(ev)
        gpu.set(x,y,playername)
    end
end