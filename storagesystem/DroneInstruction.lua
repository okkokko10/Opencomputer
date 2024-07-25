local api = require "fetch_api"

local event = require "event"
local serialization = require("serialization")
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local ti = require("trackinventories")
local Location = require "Location"

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

--- makes an instruction that is at location but doesn't do anything
---@param location table Location
function DroneInstruction.at(location)
  return DroneInstruction.make(location, location, {})

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

  event.listen("longmsg_message", function(e, localAddress, remoteAddress, port, distance, name, message)
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

return DroneInstruction
