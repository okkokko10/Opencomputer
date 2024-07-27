local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"
local Drones = require "fetch_high"
local longmsg = require "longmsg_message"

local DroneInstruction = {}

---@class DroneInstruction
---@field start_location Location
---@field finish_location Location
---@field actions DroneAction[]

--- makes a DroneInstruction
---@param start_location Location location that the instruction starts at
---@param finish_location Location
---@param actions DroneAction[]
---@return DroneInstruction
function DroneInstruction.make(start_location, finish_location, actions)
  local temp = {
    start_location = start_location,
    finish_location = finish_location,
    actions = actions
  }
  return temp
end

--- makes an instruction that is at location but doesn't do anything
---@param location Location
---@return DroneInstruction
function DroneInstruction.at(location)
  return DroneInstruction.make(location, location, {})

end

--- appends movement to the instruction
---@param self DroneInstruction
---@param location Location
---@return DroneInstruction
function DroneInstruction.moveto(self, location)
  return DroneInstruction.make(self.start_location, Location.copy(location),
    Helper.flatten({self.actions, Location.pathfind(self.finish_location, location)}))
end
-- prepends movement to instruction.
---@param self DroneInstruction
---@param location Location
---@return DroneInstruction
function DroneInstruction.movefrom(self, location)
  return DroneInstruction.make(Location.copy(location), self.finish_location,
    Helper.flatten({Location.pathfind(location, self.start_location), self.actions}))
end

--- scan the inventory
---@param iid IID
---@return DroneInstruction
function DroneInstruction.scan(iid)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.scan(iid, inv_data.side)})
end
--- take items from an inventory
---@param iid IID
---@param slot integer
---@param own_slot integer
---@param size integer
---@return DroneInstruction
function DroneInstruction.suck(iid, slot, own_slot, size)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.suck(inv_data.side, own_slot, slot, size, iid)})
end
--- put items into an inventory
---@param iid IID
---@param slot integer
---@param own_slot integer
---@param size integer
---@return DroneInstruction
function DroneInstruction.drop(iid, slot, own_slot, size)
  local inv_data = ti.getData(iid)
  local loc = Location.copy(inv_data)
  return DroneInstruction.make(loc, loc, {api.actions.drop(inv_data.side, own_slot, slot, size, iid)})
end
--- add the DroneAction to the end
---@param self DroneInstruction
---@param action DroneAction
---@return DroneInstruction
function DroneInstruction.thenDo(self, action)
  return DroneInstruction.make(self.start_location, self.finish_location, Helper.flatten({self.actions, {action}}))
end
--- echo the message at the end
---@param self DroneInstruction
---@param message string
---@return DroneInstruction
function DroneInstruction.thenEcho(self, message)
  return DroneInstruction.thenDo(self, api.actions.echo(message))
end
--- do the instructions in order. motion from one's endpoint to another's start is added between
---@param instructions DroneInstruction[]
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
--- do instructions in order.
---@param self DroneInstruction
---@param other DroneInstruction
---@return DroneInstruction
function DroneInstruction.join2(self, other)
  return DroneInstruction.make(self.start_location, other.finish_location, Helper.flatten(
    {self.actions, Location.pathfind(self.finish_location, other.start_location), other.actions}))

end

--- has the drone wait by beeping between actions
---@param self DroneInstruction
---@param seconds number
---@return DroneInstruction
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
---@param self DroneInstruction
---@param drone_address string
---@param finish_listener? fun() if set, is called when the drone reports having finished the instruction.
function DroneInstruction.execute(self, drone_address, finish_listener)
  if not Drones.isFree(drone_address) then
    error("this drone is not free")
  end
  Drones.setBusy(drone_address)
  local instruction_id = math.random()
  local finish_message = "fetcher finish " .. instruction_id
  local final = DroneInstruction.movefrom(DroneInstruction.thenEcho(self, finish_message), Drones.drones[drone_address])

  -- final = DroneInstruction.separate(final, 0.1)

  Location.copy(final.finish_location, Drones.drones[drone_address])

  longmsg.listen(function(e, localAddress, remoteAddress, port, distance, name, message)
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

---
---@param self DroneInstruction
---@param finish_listener? fun() if set, is called when the drone reports having finished the instruction.
function DroneInstruction.queueExecute(self, finish_listener)
  local f = function(address)
    DroneInstruction.execute(self, address, finish_listener)
    return true
  end
  Drones.queue(f, self.start_location)

end

return DroneInstruction
