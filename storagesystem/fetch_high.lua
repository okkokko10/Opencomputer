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

--- gets the drone with this address
---@param address string
---@return Drone
function Drones.get(address)
  return Drones.drones[address]
end

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
    api.send(address, nil, nil, api.actions.updateposition(x, y, z), api.actions.execute('d.setStatusText("f"..ver)'))
    Drones.pool_drone:register(address)
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
end

---@deprecated
function Drones.setBusy(address)
  Drones.drones[address].business = true
end

---@deprecated
function Drones.isFree(address)
  return not Drones.drones[address].business
end

--- gets a drone that is not busy
---@deprecated
---@param location? Location prioritizes drones close to this location
---@param filter? fun(address:Address):boolean does a drone fit
---@return Address?
function Drones.getFreeDrone(location, filter)
  filter = filter or function()
      return true
    end
  local temp =
    Helper.min(
    Drones.drones,
    function(drone, address)
      if drone.business or not filter(address) then
        return math.huge
      elseif not location then
        return 0
      else
        return Location.pathDistance(drone, location)
      end
    end
  )
  return temp and temp.address
end

--- sets a drone to be free. pushes a notification
---@deprecated Pool does this automatically
---@param address string
function Drones.setFree(address)
  -- event.push("thread_drone freed", address)
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

Drones.pool_drone = Pool.create()
for address, drone in pairs(Drones.drones) do
  Drones.pool_drone:register(address)
end

function Drones.registerNearby()
  api.send(nil, nil, nil, api.actions.echo("register fetcher")) -- todo move from receiveEcho
end

return Drones
