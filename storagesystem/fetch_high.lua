local api = require "fetch_api"
local Future = require "Future"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"
local filehelp = require "filehelp"
local longmsg = require "longmsg_message"
local thread = require("thread")
local Pool = require "Pool"

-- set up listener for the return message
-- buffer for requests while all drones are busy
-- only send one request to one drone.
-- status request to all drones

---@class Drone: Location, table
---@field address string
---@field business any|nil
---@field status table|nil
---last_node, x,y,z tell the location the drone will be at the end of its latest accepted instruction
---{address=, business:(order)=, nodeparent=, x=, y=, z=, status=(drone's latest status report)}

local Drones = {}

Drones.DRONES_PATH = "/usr/storage/drones.csv"

---@type table<Address,Drone> --- [address]: {address=, business:(order)=, nodeparent=, x=, y=, z=, status=(drone's latest status report)}
Drones.drones = filehelp.loadCSV(Drones.DRONES_PATH, "address")

Drones.CHARGERS_PATH = "usr/storage/chargers.txt"

--- locations of charging stations
---@type Location[]
Drones.chargers = filehelp.loadCSV(Drones.CHARGERS_PATH)

--- gets the drone with this address
---@param address string
---@return Drone
function Drones.get(address)
  return Drones.drones[address]
end

function Drones.save()
  filehelp.saveCSV(Drones.drones, Drones.DRONES_PATH)
end

local function registering(address, distance)
  Drones.drones[address] = {
    address = address
  }
  local start = distance
  local ofs = 1 / (distance * distance + 100)

  api.send(
    address,
    nil,
    nil,
    api.actions.execute("ofs=" .. ofs .. ";vel=" .. ofs),
    api.actions.move(1, 0, 0),
    api.actions.echo("register fetcher x"),
    api.actions.move(-1, 1, 0),
    api.actions.echo("register fetcher y"),
    api.actions.move(0, -1, 1),
    api.actions.echo("register fetcher z"),
    api.actions.move(0, 0, -1),
    api.actions.echo("register fetcher o"),
    api.actions.execute("ofs=0.1;vel=2")
  )
  local xd = Drones.pullEcho(address, "register fetcher x").distance
  local yd = Drones.pullEcho(address, "register fetcher y").distance
  local zd = Drones.pullEcho(address, "register fetcher z").distance
  local origin = Drones.pullEcho(address, "register fetcher o").distance

  local o2 = origin * origin
  local pos = longmsg.position

  local x = ((xd * xd - o2) - 1) * 0.5 + pos.x
  local y = ((yd * yd - o2) - 1) * 0.5 + pos.y
  local z = ((zd * zd - o2) - 1) * 0.5 + pos.z
  local closest = Nodes.findclosest(x, y, z)
  if not closest then
    Drones.drones[address] = nil
    error("no close node found")
  end
  local drone = Drones.drones[address]
  drone.x = x
  drone.y = y
  drone.z = z
  drone.nodeparent = closest.nodeid
  api.send(address, nil, nil, api.actions.updateposition(x, y, z), api.actions.execute('d.setStatusText("f"..ver)'))
  Drones.pool_drone:register(address)
end

local function receiveEcho(address, message, distance)
  if message == "register fetcher" then
    if not Drones.drones[address] then
      registering(address, distance)
    end
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
    api.send(
      address,
      nil,
      nil,
      api.actions.updateposition(drone.x, drone.y, drone.z),
      api.actions.execute('d.setStatusText("f"..ver)')
    )
  end
end

--- todo
local function drone_listener(e, localAddress, remoteAddress, port, distance, name, message)
  if (name == "status" or name == "wakeup" or name == "error") then
    local status = serialization.unserialize(message)
    updateFromStatus(status, remoteAddress, name)
  elseif (name == "echo") then
    receiveEcho(remoteAddress, message, distance)
  end
end

longmsg.listen(drone_listener)

function Drones.addDrone(address, nodeparent, x, y, z)
  Drones.drones[address] = {
    address = address,
    nodeparent = nodeparent,
    x = x,
    y = y,
    z = z
  }
  Drones.pool_drone:register(address)
end

--- pulls an echo from the drone. blocks
---@param address Address
---@param message string
---@param timeout? number seconds
---@return LongMessage?
function Drones.pullEcho(address, message, timeout)
  return longmsg.pullTable(
    {
      remoteAddress = address,
      name = "echo",
      message = message
    },
    timeout
  )
end

--- callback is called asynchronously with a drone address. during its execution that drone is reserved for it.
--- returns a future of callback.
---@generic R
---@param callback fun(address:string):R
---@param location? Location
---@param filter? fun(address:Address):boolean does a drone fit
---@return Future ---<R>
function Drones.queue(callback, location, filter)
  return Drones.pool_drone:queue(
    callback,
    function(address)
      if filter and not filter(address) then
        return nil
      elseif not location then
        return 0
      else
        return Location.pathDistance(Drones.get(address), location)
      end
    end
  ):named("dr:queue")
end

---@class DroneStatus
---@field space integer
---@field storage table[] -- same as ScanData
---@field freeMemory integer
---@field totalMemory integer
---@field energy integer
---@field maxEnergy integer
---@field uptime number
---@field x number
---@field y number
---@field z number
---@field cmd_id number|nil
---@field cmd_index integer|nil
---@field offset number
---@field extra any|nil
---@field ver string

---to be set as pool maintenance
---@param address Address
---@return boolean
function Drones.maintenanceStart(address)
  api.send(address, nil, nil, api.actions.status()) -- send the drone the instruction
  local message = longmsg.pullTable({remoteAddress = address, name = "status"})
  ---@type DroneStatus
  local status = serialization.unserialize(message.message)
  if status.energy / status.maxEnergy > 0.5 then
    return false
  else
    Drones.maintenanceMain(address)
    return true
  end
end

function Drones.maintenanceMain(address)
  local DroneInstruction = require("DroneInstruction")
  local closestCharger =
    Helper.min(
    ---@type (DroneAction_moveto[]?)[]
    Helper.map(
      Drones.chargers,
      function(value)
        return Location.pathfind(Drones.get(address), value)
      end
    ),
    Location.pathPathDistance
  )
  if not closestCharger then
    error("no chargers connected")
  end

  DroneInstruction.at(closestCharger):execute(address)
end

Drones.pool_drone = Pool.create()
for address, drone in pairs(Drones.drones) do
  Drones.pool_drone:register(address)
end

Drones.pool_drone:setMaintenance(Drones.maintenanceStart)
Drones.pool_drone:setMaintenancePeriod(60)

function Drones.registerNearby()
  api.send(nil, nil, nil, api.actions.echo("register fetcher")) -- todo move from receiveEcho
end

return Drones
