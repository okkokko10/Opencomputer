-- del /usr/lib/longmsg_message.lua; edit /usr/lib/longmsg_message.lua
longmsg = require "longmsg_message"
fa = require("fetch_api")
ti = require("trackinventories")
ih = require("inventoryhigh")
Helper = require("Helper")
Nodes = require("navigation_nodes")
Drones = require("fetch_high")

longmsg.setupDebug(100, 20)

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

inventoryhigh.move(1, 1, 2, 10, 3)
