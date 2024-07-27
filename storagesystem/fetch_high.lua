local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"
local filehelp = require "filehelp"
local longmsg = require "longmsg_message"

-- set up listener for the return message
-- buffer for requests while all drones are busy
-- only send one request to one drone.
-- status request to all drones

local Drones = {}

Drones.DRONES_PATH = "/usr/storage/drones.csv"

--- [address]: {address=, business:(order)=, nodeparent=, x=, y=, z=, status=(drone's latest status report)}
---last_node, x,y,z tell the location the drone will be at the end of its latest accepted instruction 
Drones.drones = filehelp.loadCSV(Drones.DRONES_PATH, "address")
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
  filehelp.saveCSV(Drones.drones, Drones.DRONES_PATH)
end

local registering = {}

local function receiveEcho(address, message, distance)
  if message == "register fetcher" then
    if not Drones.drones[address] then
      Drones.drones[address] = {
        address = address,
        business = true
        -- nodeparent, x, y, z are unknown
      }
      registering[address] = {distance}
      local ofs = 1 / (distance * distance + 100)

      api.send(address, nil, nil, api.actions.execute("ofs=" .. ofs), api.actions.move(1, 0, 0),
        api.actions.echo("register fetcher x"), api.actions.move(-1, 1, 0), api.actions.echo("register fetcher y"),
        api.actions.move(0, -1, 1), api.actions.echo("register fetcher z"), api.actions.move(0, 0, -1),
        api.actions.echo("register fetcher o"), api.actions.execute("ofs=0.1"))
    end
  elseif message == "register fetcher x" then
    registering[address][2] = distance
  elseif message == "register fetcher y" then
    registering[address][3] = distance
  elseif message == "register fetcher z" then
    registering[address][4] = distance
  elseif message == "register fetcher o" then
    registering[address][5] = distance
    local start, xd, yd, zd, origin = table.unpack(registering[address])
    local o2 = origin * origin
    local pos = longmsg.position

    local x = ((xd * xd - o2) - 1) * 0.5 + pos.x
    local y = ((yd * yd - o2) - 1) * 0.5 + pos.y
    local z = ((zd * zd - o2) - 1) * 0.5 + pos.z
    local closest = Nodes.findclosest(x, y, z)
    local drone = Drones.drones[address]
    drone.x = x
    drone.y = y
    drone.z = z
    drone.nodeparent = closest.nodeid
    api.send(address, nil, nil, api.actions.updateposition(x, y, z), api.actions.execute("d.setStatusText(\"f\"..ver)"))
    Drones.setFree(address)
  end
end

local function updateFromStatus(status, address, statusName)
  local drone = Drones.drones[address]
  if not drone then
    return
  end
  status.statusName = statusName
  drone.status = status
  if statusName == "wakeup" then
    -- send the drone its stored coordinates.
    api.send(address, nil, nil, api.actions.updateposition(drone.x, drone.y, drone.z),
      api.actions.execute("d.setStatusText(\"f\"..ver)"))
  end
end

local function drone_listener(e, localAddress, remoteAddress, port, distance, name, message)
  if (name == "status" or name == "wakeup" or name == "error") then
    local status = serialization.unserialize(message)
    updateFromStatus(status, remoteAddress, name)
  elseif (name == "echo") then
    receiveEcho(remoteAddress, message, distance)
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

function Drones.registerNearby()
  api.send(nil, nil, nil, api.actions.echo("register fetcher"))
end

return Drones
