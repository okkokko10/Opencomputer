local ti = require "trackinventories"
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local Drones = require "fetch_high"
local Item = require "Item"
local DroneInstruction = require "DroneInstruction"
local Recipe = require "Recipe"
local Future = require "Future"

local InventoryHigh = {}

---@class ItemFoundAt: Item
---@field foundAt table

-- returns a table of all items, with slot set to 1, size being a sum of all of that item,
-- and with an extra index: foundAt, which tracks positions that the item is found at and how many there are there
function InventoryHigh.allItems()
  ---@type table<string,ItemFoundAt>
  local all_items = {}
  local space = 0
  local space_taken = 0
  local itemcounter = 1
  for iid, inventoryData in pairs(ti.inventories) do
    if not inventoryData.isExternal then
      local items, close = ti.read(iid)
      space = space + ti.getSpace(iid)
      for slot, item in pairs(items) do
        space_taken = space_taken + 1
        local index = Item.makeIndex(item)
        local current = all_items[index]
        local size = Item.getsize(item)
        local position_info = {iid, slot, size}
        if current then
          Item.setsize(current, Item.getsize(current) + size)
          table.insert(current.foundAt, position_info)
        else
          ---@type ItemFoundAt
          local copy = Item.copy(item, itemcounter, size) -- slot set to a new one, although size should be the same regardless.
          itemcounter = itemcounter + 1
          all_items[index] = copy
          copy.foundAt = {position_info}
        end
      end
      close()
    end
  end
  return all_items, space, space_taken
end

function InventoryHigh.scanAllOne()
  local instr =
    DroneInstruction.join(
    Helper.map(
      ti.inventories,
      function(inv_data)
        return DroneInstruction.scan(inv_data.id)
      end
    )
  )
  local droneAddr = Drones.getFreeDrone()
  if droneAddr then
    return true, DroneInstruction.execute(instr, droneAddr) -- todo deprecated
  end
end

function InventoryHigh.scanAll()
  -- local instr = Helper.map(ti.inventories, function(inv_data)
  --   return DroneInstruction.scan(inv_data.id)
  -- end)
  for k, inv_data in pairs(ti.inventories) do
    DroneInstruction.scan(inv_data.id):queueExecute()
  end
end

--- takes an item from one inventory slot to another
---@param from_iid number
---@param from_slot number
---@param to_iid number
---@param to_slot number
---@param size number
---@param item? Item
---@return Future completion
function InventoryHigh.move(from_iid, from_slot, to_iid, to_slot, size, item)
  item = item or ti.getInSlot(from_iid, from_slot)
  if not item then
    return Future.createInstant(false, "no item requested")
  end
  size = size or Item.getsize(item)
  if not size or size == 0 then
    return Future.createInstant(false, "0 items requested")
  end
  if not ti.Lock.canRemove(from_iid, from_slot, size, item) then
    return Future.createInstant(false, "can't remove")
  elseif not ti.Lock.canAdd(to_iid, to_slot, size, item) then
    return Future.createInstant(false, "can't add")
  end
  ti.Lock.startRemove(from_iid, item, from_slot, size)
  ti.Lock.startAdd(to_iid, item, to_slot, size)
  local work = DroneInstruction.join2(
    DroneInstruction.suck(from_iid, from_slot, 1, size),
    DroneInstruction.drop(to_iid, to_slot, 1, size)
  ):queueExecute()
  local finish = work:onSuccess(
    function()
      ti.Lock.commitRemove(from_iid, from_slot, size)
      ti.Lock.commitAdd(to_iid, to_slot, size)
      -- todo: if a failure is detected, undo the action instead. 
      -- todo: program drones to do the completed instructions in reverse when they encounter an exception, then they echo failure.
      return true
    end
  )
  return finish
end

-- when a filter is added to, it should compare the old filtered, because adding to a filter can only remove items

local function filterItem(item, filterstring)
  for str in Helper.splitString(filterstring, " ") do
    if str[1] == "@" then
      if not string.find(Item.getMod(item), string.sub(str, 2)) then
        return false
      end
    else
      if not string.find(Item.getlabel(item), str) then
        return false
      end
    end
  end
  return true
end

-- --- how many items can be crafted
-- --- todo
-- ---@param item any
-- function InventoryHigh.amountCraftable(item)
--   Recipe.getRecipe(item)
-- end

-- -- todo
-- function InventoryHigh.Craftable(item, size, allItems)
--   local this_index = Item.makeIndex(item)

--   local expended = {
--     [this_index] = (allItems[this_index].size + size)
--   }
--   local generated = {}
--   local recipe = Recipe.getRecipe(item)
--   if not recipe then
--     return
--   end
--   for k, v in pairs(expended) do

--   end
--   local times = math.ceil(size / Item.getsize(recipe.outputItem))
--   for i = 1, #recipe.needed do
--     local ite = recipe.needed[i]
--     InventoryHigh.Craftable(ite, Item.getsize(ite) * times, allItems, expended, generated)
--   end

-- end

return InventoryHigh
