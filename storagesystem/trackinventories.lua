-- maxSize=64, maxDamage=0,label="Redstone",name="minecraft:redstone",damage=0,size=28,hasTag=false
local serialization = require("serialization")
local event = require "event"
local Helper = require "Helper"
local Item = require "Item"

-- local args, options = shell.parse(...)
-- shell.resolve(args[1])

local Inventory = {}

Inventory.Item = Item
Inventory.INVENTORIES_PATH = "/usr/storage/inventories.csv"
Inventory.FILENAME_START = "/usr/storage/invs/inv_"

-- {id=?, nodeparent=?, x=?, y=?, z=?, side=?, space=?, isExternal=?, sizeMultiplier=1, file="?/?.csv"}
Inventory.inventories = Helper.loadCSV(Inventory.INVENTORIES_PATH)

--- gets inventory data
--- counts as a Location
-- {id=?, nodeparent=?, x=?, y=?, z=?, side=?, space=?, isExternal=?, sizeMultiplier=1, file="?/?.csv"}
---@param id any
---@return table
function Inventory.getData(id)
  return Inventory.inventories[id]
end

function Inventory.makeNewInvFilePath(id)
  return Inventory.FILENAME_START .. id .. ".csv"
end

function Inventory.saveInventories() -- save the inventories file
  Helper.saveCSV(Inventory.inventories, Inventory.INVENTORIES_PATH)
end

function Inventory.set(id, contents, space) -- replaces old inventory data with contents. returns true if successful
  local inv = Inventory.inventories[id]
  if inv then
    if space and (space ~= inv.space) then
      inv.space = space
      Inventory.saveInventories()
      -- signal change? 
    end
    local file_path = inv.file
    Helper.saveCSV(contents, file_path)
    return true
  else
    error("no such inventory: " .. id)
    return false
  end
end

function Inventory.get(id) -- returns inventory, with indices set to slots and the amount of taken slots. todo: cache.
  local inv = Inventory.inventories[id]
  if inv then
    local file_path = inv.file
    local spacetaken = 0
    return Helper.mapWithKeys(Helper.loadf(file_path), function(v) -- todo: replace with Helper.loadCSV
      local t = serialization.unserialize(v)
      if t then
        spacetaken = spacetaken + 1
        return t, t[Item.slot]
      end
    end), spacetaken
  end
end

--- shorthand for Inventory.get(id)[slot]
---@param id (number | string)
---@param slot number
---@return (table | nil) Item
function Inventory.getInSlot(id, slot)
  return Inventory.get(id)[1][slot]
end

function Inventory.getSizeMultiplier(id)
  return Inventory.inventories[id].sizeMultiplier
end

function Inventory.getSpace(id)
  return Inventory.inventories[id].space
end

--- update the inventory  
--- contents_new must be added only after contents_changed has been applied.
---@param id any
---@param contents_changed table table of tuples (slot,change), representing how much the amount of something has increased or decreased
---@param contents_new table like setInventory contents
function Inventory.update(id, contents_changed, contents_new)
  local storage = Inventory.get(id)
  for slot, change in pairs(contents_changed) do
    local newsize = storage[slot][Item.size] + change
    if newsize == 0 then
      storage[slot] = nil
    elseif newsize < 0 then
      error("amount changed to below 0")
      -- todo: error
    else
      storage[slot][Item.size] = newsize
    end
  end
  for cont in contents_new do
    if storage[cont[Item.slot]] then
      error("placed item in wrong slot")
      -- todo: error
    end
    storage[cont[Item.slot]] = cont
  end
  Inventory.set(id, storage)
end

--- add or remove an amount of item from an inventory slot.
--- todo: does not check max size, does not check inventory space
---@param id any
---@param item table Item
---@param slot number|nil -- by default takes from item
---@param size number|nil -- by default takes from item
function Inventory.changeSingle(id, item, slot, size)
  slot = slot or item[Item.slot]
  size = size or item[Item.size]
  local storage = Inventory.get(id)
  local current = storage[slot]
  if current then
    if not Item.equals(item, current) then
      error("added item incompatible with current item")
    end
    local current_size = current[Item.size]
    local new_size = current_size + size
    if new_size == 0 then
      storage[slot] = nil
    elseif new_size < 0 then
      error("removing below zero")
    else
      current[Item.size] = new_size
    end
  else
    if size < 0 then
      error("removing below zero")
    elseif size > 0 then
      storage[slot] = Item.copy(item, slot, size)
    end
  end
  Inventory.set(id, storage)
end

--- call this to create a new inventory.
---@param id (number | string) = next()
---@param nodeparent (number | string) nodeparent
---@param x number
---@param y number
---@param z number
---@param side number sides
---@param isExternal boolean|nil = false
---@param sizeMultiplier number|nil = 1
---@return (number | string) id
function Inventory.makeNew(id, nodeparent, x, y, z, side, isExternal, sizeMultiplier)
  id = id or (#Inventory.inventories + 1)
  Inventory.inventories[id] = {
    id = id,
    nodeparent = nodeparent,
    x = x,
    y = y,
    z = z,
    side = side,
    space = 0,
    isExternal = isExternal or false,
    slotMultiplier = sizeMultiplier or 1,
    file = Inventory.makeNewInvFilePath(id)
  }
  return id

end

--- a part of Inventory that ensures Consistency (only modify data in allowed ways) and Isolation (transactions should either block or act sequential) from ACID
Inventory.Lock = {}
Inventory.Lock.add_max = {}
Inventory.Lock.remove_max = {}

--- can this amount of item be added to this slot?
---@param id any
---@param slot number
---@param size number
---@param item table Item
function Inventory.Lock.canAdd(id, slot, size, item)

  local current_item = Inventory.getInSlot(id, slot)
  if current_item and not Item.equals(item, current_item) then
    return false
  end
  local current_size = current_item[Item.size]

  ---@type table Item
  local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
  if current_added and not Item.equals(item, current_added) then
    return false
  end
  local current_added_size
  if current_added then
    current_added_size = current_added[Item.size]
  else
    current_added_size = 0
  end

  local sizeMult = Inventory.getSizeMultiplier(id)
  if current_size + current_added_size + size <= item[Item.maxSize] * sizeMult then
    -- the Item fits
    return true
  else
    -- the Item does not fit
    return false
  end
end
--- add to add_max, if it's valid.
---@param id any
---@param slot number
---@param size number
---@param added_item table Item
---@param precalculated_canAdd boolean|nil
function Inventory.Lock.add_add_max(id, slot, size, added_item, precalculated_canAdd)

  if precalculated_canAdd or Inventory.Lock.canAdd(id, slot, size, added_item) then
    local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
    if current_added then
      current_added[Item.size] = current_added[Item.size] + size
    else
      Inventory.Lock.add_max[Helper.makeIndex(id, slot)] = Item.copy(added_item, slot, size)
    end
    return true
  else
    return false
  end
end

--- can this amount of item be removed from this slot?
---@param id any
---@param slot number
---@param size number
---@param item table Item
function Inventory.Lock.canRemove(id, slot, size, item)

  local current_item = Inventory.getInSlot(id, slot)
  if not Item.equals(item, current_item) then
    return false
  end
  local current_removed = Inventory.Lock.remove_max[Helper.makeIndex(id, slot)]
  if current_removed and not Item.equals(item, current_removed) then
    return false
  end
  local current_removed_size
  if current_removed then
    current_removed_size = current_removed[Item.size]
  else
    current_removed_size = 0
  end

  local current_size = current_item[Item.size]

  if current_removed_size + size <= current_size then
    -- the Item fits
    return true
  else
    -- the Item does not fit
    return false
  end
end

function Inventory.Lock.add_remove_max(id, slot, size, removed_item, precalculated_canRemove)
  if precalculated_canRemove or Inventory.Lock.canRemove(id, slot, size, removed_item) then
    local current_removed = Inventory.Lock.remove_max[Helper.makeIndex(id, slot)]
    if current_removed then
      current_removed[Item.size] = current_removed[Item.size] + size
    else
      Inventory.Lock.remove_max[Helper.makeIndex(id, slot)] = Item.copy(item, slot, size)
    end
    return true
  else
    return false
  end
end

--- commits an amount of adding to a slot, making it final
---@param id any
---@param slot number
---@param size number
function Inventory.Lock.commitAdd(id, slot, size)
  local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
  local new_size = current_added[Item.size] - size
  if new_size < 0 then
    error("committing more than possible: Inventory.Lock.commitAdd(" .. id .. ", " .. slot .. ", " .. size .. ")")
  end
  current_added[Item.size] = new_size
  Inventory.changeSingle(id, current_added, slot, size)
end

--- commits an amount of removing from a slot, making it final
---@param id any
---@param slot number
---@param size number
function Inventory.Lock.commitRemove(id, slot, size)
  local current_removed = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
  local new_size = current_removed[Item.size] - size
  if new_size < 0 then
    error("committing more than possible: Inventory.Lock.commitRemove(" .. id .. ", " .. slot .. ", " .. size .. ")")
  end
  current_removed[Item.size] = new_size
  Inventory.changeSingle(id, current_removed, slot, -size)
end

--- starts adding an item to the slot.
---@param id (number | string)
---@param item table
---@param slot (nil | number)
---@param size (nil | number)
---@return boolean success
function Inventory.Lock.startAdd(id, item, slot, size)
  -- todo: need to actually order a drone
  slot = slot or item[Item.slot]
  size = size or item[Item.size]
  return Inventory.Lock.add_add_max(id, slot, size, item)

end

--- starts removing an item from the slot.
---@param id (number | string)
---@param item table
---@param slot (nil | number)
---@param size (nil | number)
---@return boolean success
function Inventory.Lock.startRemove(id, item, slot, size)
  slot = slot or item[Item.slot]
  size = size or item[Item.size]
  return Inventory.Lock.add_remove_max(id, slot, size, item)

end

--- sets the inventory according to scan data
-- todo: this currently changes data asynchronously.
-- todo: currently does not support from and to. as such, those themselves are disabled.
-- scan_data = {id=?,time_start=?,time_end=?,space=?,from=?,to=?,storage={[?]={...Item...}}}
local function updateFromScan(scan_data)
  Inventory.set(scan_data.id, scan_data.storage, scan_data.space)
end

-- automatically update inventories when scan data arrives
local function scan_data_listener(e, localAddress, remoteAddress, port, distance, name, message)
  if name ~= "scan_data" then
    return
  end
  local scan_data = serialization.unserialize(message)
  -- event.push("scan_data_message",scan_data)
  updateFromScan(scan_data)
end

local function startListening()
  return event.listen("sem_message", scan_data_listener)
end
local cancelvalue = startListening()

local function quit()
  event.cancel(cancelvalue)
  Inventory.saveInventories()
end

return Inventory
