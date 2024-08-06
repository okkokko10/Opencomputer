---@diagnostic disable

-- del /usr/lib/longmsg_message.lua; edit /usr/lib/longmsg_message.lua
longmsg = require "longmsg_message"
fa = require("fetch_api")
ti = require("trackinventories")
ih = require("inventoryhigh")
Helper = require("Helper")
Nodes = require("navigation_nodes")
Drones = require("fetch_high")

longmsg.setupDebug(100, 20)

longmsg.setupDebug(90, 10, nil, nil, "thread_drone freed")
longmsg.setupDebug(80, 5, nil, nil, "thread_drone queue")

droneaddr = next(fetch_high.drones)

ih.scanAll()

-- fa.send(nil, nil, 1, fa.actions.move(1, 0, 2), fa.actions.scan(1, sides.negx))
fa.send(nil, nil, 1, fa.actions.scan(1, sides.negx))
fa.send(nil, nil, 1, fa.actions.updateposition(5, 5, 9))

fa.send(nil, nil, 1, fa.actions.moveto(3, 4, 8))

ti.makeNew(1, 1, 4, 4, 10, sides.negx)

ih.allItems()

droneaddr = next(fetch_high.drones)
fetch_high.scan(droneaddr, 1)

fhigh.Location.pathfind(fhigh.drones[droneaddr], ti.getData(1))

ih.move(1, 1, 2, 10, 3)

-- for k, v in pairs(ih.allItems()) do print(v.size,Item.getlabel(v)) end

-- event.listen("tablet_use",function(_,tbl) print(serialization.serialize(tbl));computer.beep(200,0.1) end)

-- timer_last = 0; function timer() local temp = timer_last; timer_last = timer_func(); return timer_last - temp end; timer_func = computer.uptime

component.gpu.setActiveBuffer(1)

-- component.gpu.setActiveBuffer(1); timer(); for i = 1, 10000 do component.gpu.set(i % 100, i % 31, "ABC") end;component.gpu.setActiveBuffer(0); print(timer())
-- component.gpu.setActiveBuffer(0); timer(); for i = 1, 10000 do component.gpu.setBackground(1) end;component.gpu.setActiveBuffer(0); print(timer())

-- for i = 1,100,4 do print(i,string.char(i,i+1,i+2,i+3)) end
