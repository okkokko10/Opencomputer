local component = require "component"
local sides = require "sides"
local robot = component.robot
local serialization = require "serialization"

local ic = component.inventory_controller

local readinventory = {}

function readinventory.ownItems()
    local temp = {}
    for i = 1, robot.inventorySize() do
        temp[i] = ic.getStackInInternalSlot(i)
    end
end

function readinventory.items(side)
    -- side = side or 3
    local temp = {}
    local size, reason = ic.getInventorySize(side)
    if not size then
        return
    end
    for i = 1, size do
        temp[i] = ic.getStackInSlot(side, i)
    end
    return temp
end


local args = {...}

if args[1] == "read" then
    print(serialization.serialize(readinventory.items(3)))
end

-- print(serialization.serialize(stack))

return readinventory