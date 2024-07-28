local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"
local filehelp = require "filehelp"
local longmsg = require "longmsg_message"
local thread = require("thread")

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

---@type table<string,Drone> --- [address]: {address=, business:(order)=, nodeparent=, x=, y=, z=, status=(drone's latest status report)}
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
function Drones.setBusy(address)
  Drones.drones[address].business = true
end

function Drones.isFree(address)
  return not Drones.drones[address].business
end

--- gets a drone that is not busy
---@param location Location|nil prioritizes drones close to this location
---@param filter? fun(address:Address):boolean does a drone fit
---@return Drone|nil
function Drones.getFreeDrone(location, filter)
  filter = filter or function()
    return true
  end
  local temp = Helper.min(Drones.drones, function(drone, address)
    if drone.business or not filter(address) then
      return math.huge
    elseif not location then
      return 0
    else
      return Location.pathDistance(drone, location)
    end
  end)
  return temp and temp.address
end

--- sets a drone to be free. pushes a notification
---@param address string
function Drones.setFree(address)
  Drones.drones[address].business = nil
  event.push("thread_drone freed", address)
end

--- pulls an echo from the drone. blocks
---@param address Address
---@param message string
---@param timeout? number seconds
---@return LongMessage?
function Drones.pullEcho(address, message, timeout)
  return longmsg.pullTable({
    remoteAddress = address,
    name = "echo",
    message = message
  }, timeout)
end

--- handles Drones.queue
local thread_drone = {}
thread_drone.in_queue = {}

--- callback is called once when a drone becomes free, or immediately if there already is a free drone
---@param callback fun(address:string):boolean return true to consume, false to try later with some other drone
---@param location? Location 
---@param filter fun(address:Address):boolean does a drone fit
function Drones.queue(callback, location, filter)

  local i = #thread_drone.in_queue + 1
  table.insert(thread_drone.in_queue, i, {callback, location, filter})
  event.push("thread_drone queue", i) -- maybe make a custom method that allows sending functions

end

function thread_drone.call(callback, address)
  thread.create(function()
    Drones.setBusy(address)
    callback(address)
    Drones.setFree(address)
  end)
end

function thread_drone.freed(address)
  local drone = Drones.get(address)
  for k, v in pairs(thread_drone.in_queue) do
    local callback, location, filter = table.unpack(v)
    if filter(address) and Location.pathfind(location, drone) then
      thread_drone.in_queue[k] = nil
      thread_drone.call(callback, address)
      return
    end
  end
end

function thread_drone.queue(i)
  local callback, location, filter = table.unpack(thread_drone.in_queue[i]) --- Drones.queue

  local addr = Drones.getFreeDrone(location, filter)
  if addr then
    thread_drone.in_queue[i] = nil
    thread_drone.call(callback, addr)
  end
end

function thread_drone.main()
  while true do
    local pulled = {event.pull("thread_drone.*")} -- event.pullMultiple would also work
    if pulled[1] == "thread_drone freed" then
      local address = pulled[2]
      thread_drone.freed(address)
    elseif pulled[1] == "thread_drone queue" then
      local i = pulled[2]
      thread_drone.queue(i)
    end
  end
end

thread_drone.main_thread = thread.create(thread_drone.main)

Drones.thread_drone = thread_drone

function Drones.registerNearby()
  api.send(nil, nil, nil, api.actions.echo("register fetcher")) -- todo move from receiveEcho
end

return Drones
