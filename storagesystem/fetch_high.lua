local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"

-- set up listener for the return message
-- buffer for requests while all drones are busy
-- only send one request to one drone.
-- status request to all drones

local Drones = {}

Drones.DRONES_PATH = "/usr/storage/drones.csv"

--- [address]: {address=, business:(order)=, nodeparent=, x=, y=, z=, status=(drone's latest status report)}
---last_node, x,y,z tell the location the drone will be at the end of its latest accepted instruction 
Drones.drones = Helper.loadCSV(Drones.DRONES_PATH, "address")
-- {
--   address=,
--   business = nil,
--   location = {
--     parent = 1,
--     x = 0,
--     y = 0,
--     z = 0,
--   },
--   status = {}
-- }

function Drones.save()
  Helper.saveCSV(Drones.drones, Drones.DRONES_PATH)
end

local function receiveEcho(address, message)

end

local function updateFromStatus(status, address, statusName)
  status.statusName = statusName
  local drone = Drones.drones[address]
  drone.status = status
  if statusName == "wakeup" then
    -- todo: send the drone its stored coordinates.
    api.send(address, nil, nil, api.actions.updateposition(drone.x, drone.y, drone.z))
  end
end

local function drone_listener(e, localAddress, remoteAddress, port, distance, name, message)
  if Drones.drones[remoteAddress] then
    if (name == "status" or name == "wakeup" or name == "error") then
      local status = serialization.unserialize(message)
      updateFromStatus(status, remoteAddress, name)
    elseif (name == "echo") then
      receiveEcho(remoteAddress, message)
    end
  end
end

event.listen("longmsg_message", drone_listener)

function Drones.addDrone(address, nodeparent, x, y, z)
  Drones.drones[address] = {
    address = address,
    nodeparent = nodeparent,
    x = x,
    y = y,
    z = z
  }
end
function Drones.setBusy(address)
  Drones.drones[address].business = true
end

--- pushes an drone_freed event
---@param address string
function Drones.setFree(address)
  Drones.drones[address].business = nil
  event.push("drone_freed", address)
end

function Drones.isFree(address)
  return not Drones.drones[address].business
end

function Drones.getFreeDrone()
  local temp = Helper.find(Drones.drones, function(drone)
    return not drone.business
  end)
  return temp and temp.address
end

function Drones.scan(address, id)
  local inv_data = ti.getData(id)
  local drone = Drones.drones[address]
  local motions = Location.pathfind(drone, inv_data)
  motions[#motions + 1] = api.actions.scan(id, inv_data.side)
  Location.copy(inv_data, drone)
  return api.sendTable(address, nil, nil, (motions))
end

local instruction = {
  actions = {},
  start_location = {},
  finish_location = {}
}

return Drones
