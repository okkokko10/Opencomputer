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
---@field foundAtList FoundAt[]

---@class FoundAt
---@field [1] IID -- iid
---@field [2] integer -- slot
---@field [3] integer -- size

--todo: get max_add and max_remove for FoundAt

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
      space = space + inventoryData.space
      for slot, item in pairs(items) do
        space_taken = space_taken + 1
        local index = Item.makeIndex(item)
        local current = all_items[index]
        local size = Item.getsize(item)
        local position_info = {iid, slot, size}
        if current then
          Item.setsize(current, Item.getsize(current) + size)
          table.insert(current.foundAtList, position_info)
        else
          ---@type ItemFoundAt
          local copy = Item.copy(item, itemcounter, size) -- slot set to a new one, although size should be the same regardless.
          itemcounter = itemcounter + 1
          all_items[index] = copy
          copy.foundAtList = {position_info}
        end
      end
      close()
    end
  end
  return all_items, space, space_taken
end

---@deprecated
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
---@param from_iid IID
---@param from_slot integer
---@param to_iid IID
---@param to_slot integer
---@param size integer
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
  local work =
    DroneInstruction.join2(
    DroneInstruction.suck(from_iid, from_slot, 1, size),
    DroneInstruction.drop(to_iid, to_slot, 1, size)
  ):queueExecute()
  local finish =
    work:onSuccess(
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

--- make an ItemFoundAt with finds limited to size.
--- prioritizes stacks that have less.
--- splits stacks larger than the natural stack size into multiple.
--- returns secondary boolean foundEnough, which tells whether the main result has as much as needed
---@param item ItemFoundAt
---@param size integer
---@param filterPosition? fun(foundAt:FoundAt):boolean
---@return ItemFoundAt
---@return boolean foundEnough
function InventoryHigh.find(item, size, filterPosition)
  ---@type FoundAt[]
  local copy_foundAtList = Helper.shallowCopy(item.foundAtList)
  table.sort(
    copy_foundAtList,
    function(a, b)
      return a[3] < b[3]
    end
  )
  local totalSize = 0
  ---@type FoundAt[]
  local out = {}

  local maxSize = Item.getmaxSize(item)
  for _, list_element in ipairs(copy_foundAtList) do
    if not filterPosition or filterPosition(list_element) then
      local fullAddSize = list_element[3]
      --- if addSize is higher than the item's natural stack size, split it
      for _, addSize in ipairs(Helper.splitNumber(fullAddSize, maxSize)) do
        local added = Helper.shallowCopy(list_element)
        out[#out + 1] = added
        added[3] = addSize
        if totalSize + addSize >= size then
          added[3] = size - totalSize
          local ite = Item.copy(item, nil, size)
          ---@cast ite ItemFoundAt
          ite.foundAtList = out
          return ite, true
        end
        totalSize = totalSize + addSize
      end
    end
  end
  local ite = Item.copy(item, nil, totalSize)
  ---@cast ite ItemFoundAt
  ite.foundAtList = out
  return ite, false
end

---gathers the item from around the system
---@param to_iid IID
---@param to_slot integer
---@param size integer
---@param item Item|ItemFoundAt
---@return Future[]?
function InventoryHigh.gather(to_iid, to_slot, size, item)
  local filterPosition = function(foundAt)
    return foundAt[1] ~= to_iid
  end
  local found = InventoryHigh.find(item, size, filterPosition)
  if found then
    local completions = {}
    for _, foundAt in ipairs(found.foundAtList) do
      completions[#completions + 1] = InventoryHigh.move(foundAt[1], foundAt[2], to_iid, to_slot, foundAt[3], item)
    end
    return completions
  else
    return nil
  end
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
