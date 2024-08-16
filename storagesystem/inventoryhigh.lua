local ti = require "trackinventories"
local Helper = require "Helper"
local Nodes = require "navigation_nodes"
local Drones = require "fetch_high"
local Item = require "Item"
local DroneInstruction = require "DroneInstruction"
local Future = require "Future"
local serialization = require("serialization")

local InventoryHigh = {}

---@class ItemFoundAt: Item
---@field foundAtList FoundAt[]

--- iid, slot, removable, addable
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

---@class ScanData
---@field id IID
---@field time_start number
---@field time_end number
---@field space integer
---@field from integer
---@field to integer
---@field storage table[]
---@field contents Contents

--- gets ScanData from the return of DroneInstruction.scan(...):execute()
---@param messages LongMessage[]
---@return ScanData
function InventoryHigh.getScan(messages)
  for index, value in ipairs(messages) do
    if value.name == "scan_data" then
      local scan_data = serialization.unserialize(value.message)
      scan_data.contents = Helper.mapWithKeys(scan_data.storage, Item.parseScanned)
      return scan_data
    end
  end
  error("did not receive scan data")
end

---comment
---@param iid IID
---@return Future
function InventoryHigh.scanSingle(iid)
  return DroneInstruction.scan(iid):queueExecute():onSuccess(
    function(messages)
      local scan_data = InventoryHigh.getScan(messages)
      ti.write(scan_data.id, scan_data.contents, scan_data.space) -- todo: this in another position
      return scan_data
    end
  )
end

function InventoryHigh.scanAll()
  -- local instr = Helper.map(ti.inventories, function(inv_data)
  --   return DroneInstruction.scan(inv_data.id)
  -- end)
  local futures = {}
  for k, inv_data in pairs(ti.inventories) do
    if not inv_data.isExternal then
      futures[#futures + 1] = InventoryHigh.scanSingle(inv_data.id)
    end
  end
  return Future.combineAll(futures)
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
    return Future.createInstant(false, "no item requested"):named("ih:move")
  end
  size = size or Item.getsize(item)
  if not size or size <= 0 then
    return Future.createInstant(false, "0 items requested"):named("ih:move")
  end
  if not ti.Lock:canRemove(from_iid, from_slot, size, item) then
    return Future.createInstant(false, "can't remove"):named("ih:move")
  elseif not ti.Lock:canAdd(to_iid, to_slot, size, item) then
    return Future.createInstant(false, "can't add"):named("ih:move")
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
  return finish:named("ih:move")
end

--- if the size is higher than maxSize, split it.
---@param foundAt FoundAt
---@param maxSize integer
---@param atMost? integer -- take at most this much if it's less than the actual amount
---@param value_index? 3|4 -- split removable (3) or addable (4)?
---@return FoundAt[] -- same location as the input, but split
---@return integer left -- how much is left of atMost
local function splitFoundAt(foundAt, maxSize, atMost, value_index)
  atMost = atMost or math.huge
  value_index = value_index or 3
  local fullAddSize = math.min(foundAt[value_index], atMost)
  return Helper.map(
    Helper.splitNumber(fullAddSize, maxSize),
    function(addSize, _)
      local added = Helper.shallowCopy(foundAt)
      added[3] = 0
      added[4] = 0 -- todo: this sets addable size to 0, just to make sure.
      added[value_index] = addSize
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
---@param foundAt_value_index? 3|4 -- search for removable (3) or addable (4)
---@return ItemFoundAt
---@return false|integer notFoundEnough
function InventoryHigh.find(item, size, filterPosition, foundAt_value_index)
  foundAt_value_index = foundAt_value_index or 3
  ---@type FoundAt[]
  local copy_foundAtList = Helper.shallowCopy(InventoryHigh.getItemFoundAt(item).foundAtList)
  table.sort(
    copy_foundAtList,
    function(a, b)
      return a[foundAt_value_index] < b[foundAt_value_index]
    end
  )
  local needed = size
  ---@type FoundAt[]
  local out = {}

  local maxSize = Item.getmaxSize(item)
  for _, list_element in ipairs(copy_foundAtList) do
    if not filterPosition or filterPosition(list_element) then
      --- if addSize is higher than the item's natural stack size, split it
      local split, new_needed = splitFoundAt(list_element, maxSize, needed, foundAt_value_index)
      needed = new_needed
      for _, added in ipairs(split) do
        out[#out + 1] = added
      end
      if needed == 0 then
        break
      end
    end
  end

  local ite = Item.copy(item, nil, size - needed)
  ---@cast ite ItemFoundAt
  ite.foundAtList = out
  return ite, (needed ~= 0) and needed
end

---finds places to deposit items, as an ItemFoundAt with addables.
---
---@param item Item|ItemFoundAt
---@param size integer
---@param filterPosition? fun(foundAt:FoundAt):boolean
---@return ItemFoundAt
---@return false|integer notFoundEnough
function InventoryHigh.findDeposit(item, size, filterPosition)
  local find, notFoundEnough = InventoryHigh.find(item, size, filterPosition, 4)
  if notFoundEnough then
    -- todo: find empty slots
    local empty, notFoundEnough2 = InventoryHigh.findEmpty(notFoundEnough, Item.getmaxSize(item))
    table.move(empty, 1, #empty, #find.foundAtList + 1, find.foundAtList)
    return find, notFoundEnough2
  end
  return find, false
end

---FoundAt[] addable slots, split to maxSize
---@param needed integer
---@param maxSize integer
---@return FoundAt[]
---@return false|integer notFoundEnough
function InventoryHigh.findEmpty(needed, maxSize)
  ---@type FoundAt[]
  local out = {}

  for iid, inventoryData in pairs(ti.inventories) do
    if not inventoryData.isExternal then
      local items, close = ti.read(iid)
      for i = 1, inventoryData.space do
        if not items[i] then
          for _ = 1, inventoryData.sizeMultiplier do
            if needed == 0 then
              break
            end
            local balance = math.min(needed, maxSize)
            out[#out + 1] = {iid, i, 0, balance}
            needed = needed - balance
          end
          if needed == 0 then
            break
          end
        end
      end
      close()

      if needed == 0 then
        break
      end
    end
  end
  return out, (needed ~= 0) and needed
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
---@param targets FoundAt[] -- amount is addable, [4]
---@return Future<nil>?
function InventoryHigh.gatherSpread(item, targets)
  local itemsNeeded = 0
  for index, foundAt in ipairs(targets) do
    itemsNeeded = itemsNeeded + foundAt[4]
  end

  local found = InventoryHigh.find(item, itemsNeeded)
  if not found then
    return nil
  end
  return InventoryHigh.moveMany(item, found.foundAtList, targets)
end

--- moves items from "from" to "to"
--- at the end, items are removed from the places listed by "from" removable, and added to "to" addable
---@param item Item
---@param from FoundAt[]
---@param to FoundAt[]
---@return Future|Future<[FoundAt[],FoundAt[]]>
function InventoryHigh.moveMany(item, from, to)
  local completions = {}
  local i = 1
  --- size still needed at to[i]
  if not to[1] then
    error("to is empty" .. " " .. serialization.serialize({item, "from:", from, "to:", to}, math.huge), 2)
  end
  local needed_here = to[1][4]
  for index, foundAt in ipairs(from) do
    local size = foundAt[3]
    while size > 0 do
      if needed_here == 0 then
        i = i + 1
        needed_here = to[i][4]
      end
      local balanced_size = math.min(size, needed_here)
      completions[#completions + 1] =
        InventoryHigh.move(foundAt[1], foundAt[2], to[i][1], to[i][2], balanced_size, item)
      size = size - balanced_size
      needed_here = needed_here - balanced_size
    end
  end
  return Future.combineAll(completions, nil, {from, to}):named("ih:moveMany")
end

---move an item stack from this slot to an appropriate place
---@param iid IID
---@param slot integer
---@param item Item
---@param size integer
---@return Future|Future<[FoundAt[], FoundAt[]]>
function InventoryHigh.import(iid, slot, item, size)
  local itemFoundAt = InventoryHigh.getItemFoundAt(item)
  local deposit = InventoryHigh.findDeposit(itemFoundAt, size)
  return InventoryHigh.moveMany(item, {{iid, slot, size, 0}}, deposit.foundAtList):named("import")
end

---scans an inventory and moves things to the storage from there.
---returns Future: what items were found
---@param from_iid IID
---@param from_slot integer|nil -- if nil, import all
---@param to_slot integer|nil -- if nil, equal to from_slot
---@return Future|Future<Contents>
function InventoryHigh.importUnknown(from_iid, from_slot, to_slot)
  return DroneInstruction.scan(from_iid, from_slot, to_slot or from_slot):queueExecute():onSuccess(
    function(messages)
      local scan_data = InventoryHigh.getScan(messages)
      local futures = {}
      for index, itemstack in pairs(scan_data.contents) do
        futures[#futures + 1] = InventoryHigh.import(from_iid, index, itemstack, Item.getsize(itemstack))
      end
      Future.joinAll(futures)
      return scan_data.contents
    end
  )
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
