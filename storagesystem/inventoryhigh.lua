local ti = require "trackinventories"
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local Drones = require "fetch_high"
local Item = require "Item"
local DroneInstruction = require "DroneInstruction"

local InventoryHigh = {}

-- returns a table of all items, with slot set to 1, size being a sum of all of that item, 
-- and with an extra index: foundAt, which tracks positions that the item is found at and how many there are there
function InventoryHigh.allItems()
  local all_items = {}
  local space = 0
  local space_taken = 0
  for id, inventory in pairs(ti.inventories) do
    local items, taken_slots = ti.get(id)
    space = space + ti.getSpace(id)
    space_taken = space_taken + taken_slots
    if not inventory.isExternal then
      for slot, item in pairs(items) do
        local index = Item.makeIndex(item)
        local current = all_items[index]
        local size = Item.getsize(item)
        local position_info = {id, slot, size}
        if current then
          Item.setsize(current, Item.getsize(item) + size)
          table.insert(current.foundAt, position_info)
        else
          local copy = Item.copy(item, 1, size) -- slot set to 1, although size should be the same regardless.
          all_items[index] = copy
          copy.foundAt = {position_info}
        end
      end
    end
  end
  return all_items, space, space_taken

end

function InventoryHigh.scanAll()
  local instr = DroneInstruction.join(Helper.map(ti.inventories, function(inv_data)
    return DroneInstruction.scan(inv_data.id)
  end))
  local dron = Drones.getFreeDrone()
  if dron then
    return true, DroneInstruction.execute(instr, dron)

  end
end

--- takes an item and 
function InventoryHigh.find()

end

return InventoryHigh
