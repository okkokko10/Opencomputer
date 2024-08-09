local Pool = require "Pool"
local Helper = require "Helper"
local InventoryHigh = require "inventoryhigh"
local Future = require "Future"

---@class Station
local Station = {}

---@class StationInstance
---@field class string
---@field getInputSlots fun(self)

---@type Pool --<StationInstance>
Station.pool = Pool.create()

---@alias InventorySlot [IID,integer]

Station.classes = {}

---@class CraftingRobot: StationInstance
---@field iid IID
Station.classes.craftingRobot = {
    class = "crafting"
}
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
                return {invSlot[1], invSlot[2], size}
            end
        )
        futures[#futures + 1] = InventoryHigh.gatherSpread(value, targetsAt)
    end
    return Future.combineAll(futures)
end

---do whatever is needed to activate the station. returns future of the activation
---@param stationInstance StationInstance
---@param times integer
---@return Future
function Station.activateStation(stationInstance, times)
    return stationInstance:activateStation(times)
end

function Station.emptyOutputs(stationInstance, recipe, times)
    ---@type InventorySlot[]
    local outputs = stationInstance:getOutputSlots()
    local futures = {}
    for index, value in ipairs(outputs) do
        futures[#futures + 1] = InventoryHigh.import(value[1], value[2])
    end
    return Future.combineAll(futures)
end

---@param stationInstance StationInstance
---@param recipe Recipe
---@param times integer -- watch out: should not be larger than what can be stacked.
function Station.executeRecipe(stationInstance, recipe, times)
    Station.prepareRecipe(stationInstance, recipe, times):awaitResult()
    Station.activateStation(stationInstance, times):awaitResult()
    Station.emptyOutputs(stationInstance, recipe, times):awaitResult()
end

function Station.register(station)
    -- todo
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

return Station
