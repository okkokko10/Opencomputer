local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")

-- set up listener for the return message
-- buffer for requests while all drones are busy
-- only send one request to one drone.
-- status request to all drones

-- {nodeparent=, x=, y=, z=}
-- class for locations connected to a navigation node. a node also happens to be a Location.
local Location = {}

--- shorthand for fetch_api.actions.moveto
---@param self table Location
function Location.moveto(self)
  return {
    type = "moveto",
    x = self.x,
    y = self.y,
    z = self.z
  }

end
--- returns list of moveto commands to move from Location self to Location other
---@param self table Location
---@param other table Location
---@return table|nil
function Location.pathfind(self, other)
  -- might repeat positions at the start and end
  local pathids = Nodes.pathbetween(self.nodeid or Nodes.parent(self), other.nodeid or Nodes.parent(other))
  if not pathids then
    return -- no path available
  end
  local pathloc = Helper.map(pathids, function(id)
    return Location.moveto(Nodes.get(id))
  end)
  pathloc[#pathloc + 1] = Location.moveto(other)
  return pathloc
end

--- modifies target: copies location data of base to target. leave nil to get a new copy
---@param base table Location
---@param target table|nil Location
---@return table target
function Location.copy(base, target)
  target = target or {}
  target.nodeparent = Nodes.parent(base)
  target.x = base.x
  target.y = base.y
  target.z = base.z
  return target
end

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

event.listen("sem_message", drone_listener)

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
local DroneInstruction = {}

--- func desc
---@param start_location table location that the instruction starts at
---@param finish_location table location
---@param actions table list of actions
function DroneInstruction.make(start_location, finish_location, actions)
  local temp = {
    start_location = start_location,
    finish_location = finish_location,
    actions = actions
  }
  return temp

end

--- appends movement to the instruction
---@param instruction table
---@param location table
function DroneInstruction.moveto(self, location)
  return DroneInstruction.make(self.start_location, Location.copy(location),
    Helper.flatten({self.actions, Location.pathfind(self.finish_location, location)}))
end
-- prepends movement to instruction.
function DroneInstruction.movefrom(self, location)
  return DroneInstruction.make(Location.copy(location), self.finish_location,
    Helper.flatten({Location.pathfind(location, self.start_location), self.actions}))
end

function DroneInstruction.scan(iid)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.scan(iid, inv_data.side)})
end

function DroneInstruction.suck(iid, slot, own_slot, size)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.suck(inv_data.side, own_slot, slot, size, iid)})
end
function DroneInstruction.drop(iid, slot, own_slot, size)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.drop(inv_data.side, own_slot, slot, size, iid)})
end
function DroneInstruction.thenDo(self, action)
  return DroneInstruction.make(self.start_location, self.finish_location, Helper.flatten({self.actions, {action}}))
end
function DroneInstruction.thenEcho(self, message)
  return DroneInstruction.thenDo(self, api.actions.echo(message))
end

function DroneInstruction.join(instructions)

  local actions = Helper.flatten({instructions[1].actions})
  local start_location = instructions[1].start_location
  local finish_location = instructions[1].finish_location
  for i = 2, #instructions do
    local other = instructions[i]
    actions = Helper.flatten({Location.pathfind(finish_location, other.start_location), other.actions}, actions)
    finish_location = other.finish_location
  end
  return DroneInstruction.make(start_location, finish_location, actions)

end

function DroneInstruction.join2(instruction1, instruction2)
  return DroneInstruction.make(instruction1.start_location, instruction2.finish_location,
    Helper.flatten({instruction1.actions, Location.pathfind(instruction1.finish_location, instruction2.start_location),
                    instruction2.actions}))

end

function DroneInstruction.separate(self, seconds)
  seconds = seconds or 0.5
  local temp = Helper.mapWithKeys(self.actions, function(v, i)
    return v, i * 2
  end)
  for i = 1, 2 * (#self.actions), 2 do
    temp[i] = api.actions.beep(math.max(100 - i, 40), seconds)
  end
  return DroneInstruction.make(self.start_location, self.finish_location, temp)

end

--- sets the drone to do the instruction.
---@param instruction table DroneInstruction
---@param drone_address string
---@param finish_listener function|nil if set, is called when the drone reports having finished the instruction.
function DroneInstruction.execute(instruction, drone_address, finish_listener)
  if not Drones.isFree(drone_address) then
    error("this drone is not free")
  end
  Drones.setBusy(drone_address)
  local instruction_id = math.random()
  local finish_message = "fetcher finish " .. instruction_id
  local final = DroneInstruction.movefrom(instruction, Drones.drones[drone_address])
  final = DroneInstruction.thenEcho(final, finish_message)
  -- final = DroneInstruction.separate(final, 0.1)

  Location.copy(final.finish_location, Drones.drones[drone_address])

  event.listen("sem_message", function(e, localAddress, remoteAddress, port, distance, name, message)
    if remoteAddress == drone_address and name == "echo" and message == finish_message then
      Drones.setFree(drone_address)
      if finish_listener then
        finish_listener()
      end
      return false
    end
  end)
  return api.sendTable(drone_address, nil, instruction_id, final.actions)

end

Drones.Location = Location
Drones.DroneInstruction = DroneInstruction
return Drones
