local Pool = require "Pool"
local Helper = require "Helper"
local InventoryHigh = require "inventoryhigh"
local Future = require "Future"
local longmsg_message = require "longmsg_message"
local filehelp = require "filehelp"

---@class Station
local Station = {}

---@class StationInstance
---@field id string
---@field class string
---@field getInputSlots fun(self):InventorySlot[]
---@field getOutputSlots fun(self):InventorySlot[]
---@field activateStation fun(self,times) -- blocks

---@type Pool --<StationInstance>
Station.pool = Pool.create()

---@alias InventorySlot [IID,integer]

Station.classes = {}

---@class CraftingRobot: StationInstance
---@field iid IID
---@field address Address
Station.classes.craftingRobot = {
    class = "crafting"
}
Station.classes.craftingRobot.__index = Station.classes.craftingRobot

---gets InventorySlots to put items in.
---@param self CraftingRobot
---@return InventorySlot[]
function Station.classes.craftingRobot.getInputSlots(self)
    return Helper.map(
        {1, 2, 3, 5, 6, 7, 9, 10, 11},
        function(value, key)
            return {self.iid, value}
        end
    )
end
function Station.classes.craftingRobot.getOutputSlots(self)
    return {{self.iid, 13}}
end

function Station.classes.craftingRobot.activateStation(self, times)
    longmsg_message.sendmessage("craft_command", tostring(times), nil, self.address)
    longmsg_message.pullTable({remoteAddress = self.address, name = "craft_complete"})
    -- todo: create crafter program
end

---places the items for the recipe in the station
---@param stationInstance StationInstance
---@param recipe Recipe
---@param times integer -- watch out: should not be larger than what can be stacked.
function Station.prepareRecipe(stationInstance, recipe, times)
    local inputSlots = stationInstance:getInputSlots()
    local futures = {}
    for index, value in ipairs(recipe.needed) do
        ---@type FoundAt[]
        local targetsAt =
            Helper.map(
            recipe.using[index],
            function(value, key)
                local invSlot = inputSlots[value[1]]
                local size = value[2] * times
                return {invSlot[1], invSlot[2], 0, size}
            end
        )
        futures[#futures + 1] = InventoryHigh.gatherSpread(value, targetsAt)
    end
    return Future.combineAll(futures)
end

---do whatever is needed to activate the station. blocks until completion
---@param stationInstance StationInstance
---@param times integer
function Station.activateStation(stationInstance, times)
    stationInstance:activateStation(times)
end

function Station.emptyOutputs(stationInstance, recipe, times)
    ---@type InventorySlot[]
    local outputs = stationInstance:getOutputSlots()
    local futures = {}
    for index, value in ipairs(outputs) do
        futures[#futures + 1] = InventoryHigh.importUnknown(value[1], value[2])
    end
    return Future.combineAll(futures)
end

---@param stationInstance StationInstance
---@param recipe Recipe
---@param times integer -- watch out: should not be larger than what can be stacked.
function Station.executeRecipe(stationInstance, recipe, times)
    Station.prepareRecipe(stationInstance, recipe, times):awaitResult()
    Station.activateStation(stationInstance, times)
    Station.emptyOutputs(stationInstance, recipe, times):awaitResult()
end

---comment
---@param stationInstance StationInstance
function Station.register(stationInstance)
    Station.pool:register(stationInstance)
    -- todo: save instances
end

---comment
---@param recipe Recipe
function Station.queue(recipe, times)
    local stationClass = recipe.stationType
    return Station.pool:queue(
        ---@param stationInstance StationInstance
        function(stationInstance)
            return Station.executeRecipe(stationInstance, recipe, times)
        end,
        function(stationInstance) -- fitness: is correct station.
            if stationInstance.class == stationClass then
                return 0
            else
                return nil
            end
        end
    )
end

Station.STATIONS_PATH = "/usr/storage/stations.txt"

for index, value in ipairs(filehelp.loadCSV(Station.STATIONS_PATH)) do
    Station.register(setmetatable(value, Station.classes[value.metatable]))
end

function Station.save()
    filehelp.saveCSV(
        Helper.map(
            Station.pool.objects,
            function(value, key)
                return value.object
            end
        ),
        Station.STATIONS_PATH
    )
end

return Station
