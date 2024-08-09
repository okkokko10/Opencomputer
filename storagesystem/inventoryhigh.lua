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
---@field [4] integer -- addable size

--todo: get max_add and max_remove for FoundAt

-- todo: save allItems.
-- returns a table of all items, with slot set to 1, size being a sum of all of that item,
-- and with an extra index: foundAt, which tracks positions that the item is found at and how many there are there
---@return table<itemIndex, ItemFoundAt> all_items
---@return integer space
---@return integer space_taken
function InventoryHigh.allItems()
  ---@type table<itemIndex,ItemFoundAt>
  local all_items = {}
  local space = 0
  local space_taken = 0
  local itemcounter = 0
  for iid, inventoryData in pairs(ti.inventories) do
    if not inventoryData.isExternal then
      local items, close = ti.read(iid)
      space = space + inventoryData.space
      for slot, item in pairs(items) do
        space_taken = space_taken + 1

        -- local size = Item.getsize(item)

        local size = ti.Lock:sizeRemovable(iid, slot, item)
        local addable = ti.Lock:sizeAddable(iid, slot, item)

        local position_info = {iid, slot, size, addable}

        local index = Item.makeIndex(item)
        local current = all_items[index]
        if current then
          Item.addsize(current, size)
          table.insert(current.foundAtList, position_info)
        else
          itemcounter = itemcounter + 1
          ---@type ItemFoundAt
          local copy = Item.copy(item, itemcounter, size) -- slot set to a new one, although size should be the same regardless.
          copy.foundAtList = {position_info}
          all_items[index] = copy
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
    DroneInstruction.scan(inv_data.id):queueExecute() -- todo: make a combined future.
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
  if not size or size <= 0 then
    return Future.createInstant(false, "0 items requested")
  end
  if not ti.Lock:canRemove(from_iid, from_slot, size, item) then
    return Future.createInstant(false, "can't remove")
  elseif not ti.Lock:canAdd(to_iid, to_slot, size, item) then
    return Future.createInstant(false, "can't add")
  end
  local commitRemove = ti.Lock:startRemove(from_iid, from_slot, size, item) or error("this remove should go through")
  local commitAdd = ti.Lock:startAdd(to_iid, to_slot, size, item) or error("this add should go through")
  local work =
    DroneInstruction.join2(
    DroneInstruction.suck(from_iid, from_slot, 1, size),
    DroneInstruction.drop(to_iid, to_slot, 1, size)
  ):queueExecute()
  local finish =
    work:onSuccess(
    function()
      commitRemove()
      commitAdd()
      -- todo: if a failure is detected, undo the action instead.
      -- todo: program drones to do the completed instructions in reverse when they encounter an exception, then they echo failure.
      return true
    end
  )
  return finish
end

--- if the size is higher than maxSize, split it.
---@param foundAt FoundAt
---@param maxSize integer
---@param atMost? integer -- take at most this much if it's less than the actual amount
---@return FoundAt[] -- same location as the input, but split
---@return integer left -- how much is left of atMost
local function splitFoundAt(foundAt, maxSize, atMost)
  atMost = atMost or math.huge
  local fullAddSize = math.min(foundAt[3], atMost)
  return Helper.map(
    Helper.splitNumber(fullAddSize, maxSize),
    function(addSize, _)
      local added = Helper.shallowCopy(foundAt)
      added[3] = addSize
      added[4] = 0 -- todo: this sets addable size to 0, just to make sure.
      return added
    end
  ), atMost - fullAddSize
end

---if item is not ItemFoundAt, get its corresponding one.
---returns an item with 0 size if there is none
---@param item Item|ItemFoundAt
---@return ItemFoundAt
function InventoryHigh.getItemFoundAt(item)
  if item.foundAtList then
    return item
  else
    local all_items = InventoryHigh.allItems()
    local out = all_items[Item.makeIndex(item)]
    if not out then
      out = Item.copy(item, 0, 0)
      ---@cast out ItemFoundAt
      out.foundAtList = {}
    end
    return out
  end
end

--- make an ItemFoundAt with finds limited to size.
--- prioritizes stacks that have less.
--- splits stacks larger than the natural stack size into multiple.
--- returns secondary boolean foundEnough, which tells whether the main result has as much as needed.
--- todo: foundAt addable size is not preserved
---@param item Item|ItemFoundAt
---@param size integer
---@param filterPosition? fun(foundAt:FoundAt):boolean -- return false to not take from this
---@return ItemFoundAt
---@return boolean foundEnough
function InventoryHigh.find(item, size, filterPosition)
  ---@type FoundAt[]
  local copy_foundAtList = Helper.shallowCopy(InventoryHigh.getItemFoundAt(item).foundAtList)
  table.sort(
    copy_foundAtList,
    function(a, b)
      return a[3] < b[3]
    end
  )
  local totalSize = 0 -- todo factor this out
  local needed = size
  ---@type FoundAt[]
  local out = {}

  local maxSize = Item.getmaxSize(item)
  for _, list_element in ipairs(copy_foundAtList) do
    if not filterPosition or filterPosition(list_element) then
      --- if addSize is higher than the item's natural stack size, split it
      local split, new_needed = splitFoundAt(list_element, maxSize, needed)
      needed = new_needed
      for _, added in ipairs(split) do
        out[#out + 1] = added
        totalSize = totalSize + added[3]
      end
      assert(totalSize == size - needed)
      if needed == 0 then
        break
      end
    end
  end
  assert(totalSize == size - needed)

  local ite = Item.copy(item, nil, size - needed)
  ---@cast ite ItemFoundAt
  ite.foundAtList = out
  return ite, (needed == 0)
end

---gathers the item from around the system
--- returns a future that succeeds when all of the item is gathered
---@param to_iid IID
---@param to_slot integer
---@param size integer
---@param item Item|ItemFoundAt
---@return Future<nil>?
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
    return Future.combineAll(completions)
  else
    return nil
  end
end

---gathers the item from around the system
--- returns a future that succeeds when all of the item is gathered
--- puts the item in each of the slots
---@param item Item|ItemFoundAt
---@param targets FoundAt[]
---@return Future<nil>?
function InventoryHigh.gatherSpread(item, targets)
  local itemsNeeded = 0
  for index, foundAt in ipairs(targets) do
    itemsNeeded = itemsNeeded + foundAt[3]
  end

  local found = InventoryHigh.find(item, itemsNeeded)
  if found then
    local completions = {}
    local i = 1
    --- size still needed at targets[i]
    local needed_here = targets[1][3]
    for _, foundAt in ipairs(found.foundAtList) do
      local size = foundAt[3]
      while size > 0 do
        if needed_here == 0 then
          i = i + 1
          needed_here = targets[i][3]
        end
        local balanced_size = math.min(size, needed_here)
        completions[#completions + 1] =
          InventoryHigh.move(foundAt[1], foundAt[2], targets[i][1], targets[i][2], balanced_size, item)
        size = size - balanced_size
        needed_here = needed_here - balanced_size
      end
    end
    return Future.combineAll(completions)
  else
    return nil
  end
end

---comment
---@param from_iid IID
---@param from_slot integer|nil
---@return Future<Item>
function InventoryHigh.import(from_iid, from_slot)
  ---todo
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
