local serialization = require "serialization"

local longmsg = require("longmsg_message")

local actions = {}

function actions.move(dx, dy, dz)
  -- for st in steps do
  -- 	local dx,dy,dz = table.unpack(st)
  --   checkArg(1,dx,"number"); checkArg(1,dy,"number"); checkArg(1,dz,"number")
  -- end
  return {
    type = "move",
    dx = dx,
    dy = dy,
    dz = dz
  }
end

function actions.moveto(x, y, z)
  return {
    type = "moveto",
    x = x,
    y = y,
    z = z
  }
end

function actions.scan(id, side, from, to) -- id: any side: number[, from: number, to: number]
  -- currently the other parts of the system does not support from or to
  return {
    type = "scan",
    id = id,
    side = side,
    from = nil,
    to = nil
  }
end

function actions.suck(side, own_slot, slot, size, iid)
  return {
    type = "suck",
    side = side,
    own_slot = own_slot,
    size = size,
    iid = iid -- inventory id metadata
  }
end
function actions.drop(side, own_slot, slot, size, iid)
  return {
    type = "drop",
    side = side,
    own_slot = own_slot,
    size = size,
    iid = iid -- inventory id metadata
  }
end

function actions.suckall(side) -- sucks as many items as it can from an inventory. use on an external inventory
  return {
    type = "suckall",
    side = side
  }
end

-- function actions.permutate(order)
-- 	-- could be composed from suck and drop clientside.
-- end

function actions.execute(code)
  return {
    type = "execute",
    code = code
  }
end

function actions.setWakeMessage(message, fuzzy) -- message: string[, fuzzy:boolean]
  return {
    type = "setWakeMessage",
    message = message,
    fuzzy = fuzzy
  }
end
function actions.shutdown(reboot)
  return {
    type = "shutdown",
    reboot = reboot
  }
end
function actions.beep(frequency, duration)
  return {
    type = "beep",
    frequency = frequency,
    duration = duration
  }
end
function actions.status()
  return {
    type = "status"
  }
end

function actions.echo(message)
  return {
    type = "echo",
    message = message
  }
end

function actions.updateposition(x, y, z) -- sets the drone's position tracker to these values
  return {
    type = "updateposition",
    x = x,
    y = y,
    z = z
  }
end

local function send(address, port, id, ...) -- address: string or nil, port: int or nil, id: string or number or nil, ...: actions
  id = id or math.random()
  local message = serialization.serialize({...})
  longmsg.actualmessage(address, port, "fetcher", id, message)
  return id, message
end
local function sendTable(address, port, id, orders) -- address: string or nil, port: int or nil, id: string or number or nil, ...: actions
  id = id or math.random()
  local message = serialization.serialize(orders)
  longmsg.actualmessage(address, port, "fetcher", id, message)
  return id, message
end

return {
  actions = actions,
  send = send,
  sendTable = sendTable
}
