-- maxSize=64, maxDamage=0,label="Redstone",name="minecraft:redstone",damage=0,size=28,hasTag=false
local serialization = require("serialization")
local event = require "event"
local Helper = require "Helper"
local Item = require "Item"
local filehelp = require "filehelp"
local longmsg = require "longmsg_message"

-- local args, options = shell.parse(...)
-- shell.resolve(args[1])

local Inventory = {}

---@alias Contents Item[]
---@alias IID number|string

Inventory.Item = Item
Inventory.INVENTORIES_PATH = "/usr/storage/inventories.csv"
Inventory.FILENAME_START = "/usr/storage/invs/inv_"

-- {id=?, nodeparent=?, x=?, y=?, z=?, side=?, space=?, isExternal=?, sizeMultiplier=1, file="?/?.csv"}
Inventory.inventories = filehelp.loadCSV(Inventory.INVENTORIES_PATH)

--- gets inventory data
--- counts as a Location
-- {id=?, nodeparent=?, x=?, y=?, z=?, side=?, space=?, isExternal=?, sizeMultiplier=1, file="?/?.csv"}
---@param iid IID
---@return table
function Inventory.getData(iid)
  return Inventory.inventories[iid]
end

function Inventory.makeNewInvFilePath(iid)
  return Inventory.FILENAME_START .. iid .. ".csv"
end

function Inventory.saveInventories() -- save the inventories file
  filehelp.saveCSV(Inventory.inventories, Inventory.INVENTORIES_PATH)
end

--- replaces old inventory data with contents. returns true if successful
---@param iid IID
---@param contents Contents
---@param space integer|nil
function Inventory.write(iid, contents, space)
  local inv = Inventory.inventories[iid]
  if inv then
    if space and (space ~= inv.space) then
      inv.space = space
      Inventory.saveInventories()
      -- signal change? 
    end
    local file_path = inv.file
    filehelp.saveCSV(contents, file_path)
    return true
  else
    error("no such inventory: " .. iid)
    return false
  end
end

--- returns inventory, with indices set to slots and the amount of taken slots.
--- is cached
---@param id IID
---@return Contents
---@return fun(write:boolean|nil):nil close(write) -- call this when closing. write is required to be true if the contents have been modified. not doing so is undefined 
---@return integer space taken
function Inventory.read(id)
  local inv = Inventory.inventories[id]
  if inv then
    local file_path = inv.file
    local spacetaken = 0
    local contents = Helper.mapWithKeys(filehelp.loadf(file_path), function(v) -- todo: replace with filehelp.loadCSV
      local t = serialization.unserialize(v)
      if t then
        spacetaken = spacetaken + 1
        return t, Item.getslot(t)
      end
    end)
    return contents, function(write)
      if write then
        Inventory.write(id, contents)
      end
    end, spacetaken
  else
    error("no such inventory")
  end
end

--- shorthand for Inventory.get(id)[slot]
---@param id IID
---@param slot number
---@return Item
function Inventory.getInSlot(id, slot)
  local contents, close = Inventory.read(id)
  local temp = contents[slot]
  close()
  return temp
end

function Inventory.getSizeMultiplier(id)
  return Inventory.inventories[id].sizeMultiplier
end

function Inventory.getSpace(id)
  return Inventory.inventories[id].space
end

--- update the inventory  
--- contents_new must be added only after contents_changed has been applied.
---@param id IID
---@param contents_changed table table of tuples (slot,change), representing how much the amount of something has increased or decreased
---@param contents_new table like setInventory contents
function Inventory.update(id, contents_changed, contents_new)
  local storage, close = Inventory.read(id)
  for slot, change in pairs(contents_changed) do
    local newsize = Item.getsize(storage[slot]) + change
    if newsize == 0 then
      storage[slot] = nil
    elseif newsize < 0 then
      error("amount changed to below 0")
      -- todo: error
    else
      Item.setsize(storage[slot], newsize)
    end
  end
  for cont in contents_new do
    if storage[Item.getslot(cont)] then
      error("placed item in wrong slot")
      -- todo: error
    end
    storage[Item.getslot(cont)] = cont
  end
  close(true)
end

--- add or remove an amount of item from an inventory slot.
--- todo: does not check max size, does not check inventory space
---@param id IID
---@param item Item
---@param slot number|nil -- by default takes from item
---@param size number|nil -- by default takes from item
function Inventory.changeSingle(id, item, slot, size)
  slot = slot or Item.getslot(item)
  size = size or Item.getsize(item)
  local storage, close = Inventory.read(id)
  local current = storage[slot]
  if current then
    if not Item.equals(item, current) then
      close()
      error("added item incompatible with current item")
    end
    local current_size = Item.getsize(current)
    local new_size = current_size + size
    if new_size == 0 then
      storage[slot] = nil
    elseif new_size < 0 then
      close()
      error("removing below zero")
    else
      Item.setsize(current, new_size)
    end
  else
    if size < 0 then
      close()
      error("removing below zero")
    elseif size > 0 then
      storage[slot] = Item.copy(item, slot, size)
    end
  end
  close(true)
end

--- call this to create a new inventory.
---@param id IID = next()
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
    sizeMultiplier = sizeMultiplier or 1,
    file = Inventory.makeNewInvFilePath(id)
  }
  return id

end

--- a part of Inventory that ensures Consistency (only modify data in allowed ways) and Isolation (transactions should either block or act sequential) from ACID
Inventory.Lock = {}
Inventory.Lock.add_max = {}
Inventory.Lock.remove_max = {}

--- can this amount of item be added to this slot?
---@param id IID
---@param slot number
---@param size number
---@param item Item
---@return boolean|integer if true, how much at most
function Inventory.Lock.canAdd(id, slot, size, item)

  local current_item = Inventory.getInSlot(id, slot)
  if current_item and not Item.equals(item, current_item) then
    return false
  end
  local current_size = current_item and Item.getsize(current_item) or 0

  ---@type table Item
  local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
  if current_added and not Item.equals(item, current_added) then
    return false
  end
  local current_added_size
  if current_added then
    current_added_size = Item.getsize(current_added)
  else
    current_added_size = 0
  end

  local sizeMult = Inventory.getSizeMultiplier(id)
  local maxAddable = Item.getmaxSize(item) * sizeMult - current_size - current_added_size
  if size <= maxAddable and maxAddable > 0 then
    -- the Item fits
    return maxAddable
  else
    -- the Item does not fit
    return false
  end
end
--- add to add_max, if it's valid.
---@param id IID
---@param slot number
---@param size number
---@param added_item Item
---@param precalculated_canAdd boolean|nil
function Inventory.Lock.add_add_max(id, slot, size, added_item, precalculated_canAdd)

  if precalculated_canAdd or Inventory.Lock.canAdd(id, slot, size, added_item) then
    local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
    if current_added then
      Item.setsize(current_added, Item.getsize(current_added) + size)
    else
      Inventory.Lock.add_max[Helper.makeIndex(id, slot)] = Item.copy(added_item, slot, size)
    end
    return true
  else
    return false
  end
end

--- can this amount of item be removed from this slot?
---@param id IID
---@param slot integer
---@param size integer
---@param item Item
---@return boolean|integer if true, how much at most
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
    current_removed_size = Item.getsize(current_removed)
  else
    current_removed_size = 0
  end

  local current_size = Item.getsize(current_item)

  local maxRemovable = current_size - current_removed_size

  if size <= maxRemovable and maxRemovable > 0 then
    -- the Item fits
    return maxRemovable
  else
    -- the Item does not fit
    return false
  end
end

function Inventory.Lock.add_remove_max(id, slot, size, removed_item, precalculated_canRemove)
  if precalculated_canRemove or Inventory.Lock.canRemove(id, slot, size, removed_item) then
    local current_removed = Inventory.Lock.remove_max[Helper.makeIndex(id, slot)]
    if current_removed then
      Item.setsize(current_removed, Item.getsize(current_removed) + size)
    else
      Inventory.Lock.remove_max[Helper.makeIndex(id, slot)] = Item.copy(removed_item, slot, size)
    end
    return true
  else
    return false
  end
end

--- commits an amount of adding to a slot, making it final
---@param id IID
---@param slot integer
---@param size integer
function Inventory.Lock.commitAdd(id, slot, size)
  local current_added = Inventory.Lock.add_max[Helper.makeIndex(id, slot)]
  local new_size = Item.getsize(current_added) - size
  if new_size < 0 then
    error("committing more than possible: Inventory.Lock.commitAdd(" .. id .. ", " .. slot .. ", " .. size .. ")")
  end
  if new_size == 0 then
    Inventory.Lock.add_max[Helper.makeIndex(id, slot)] = nil
  else
    Item.setsize(current_added, new_size)
  end
  Inventory.changeSingle(id, current_added, slot, size)
end

--- commits an amount of removing from a slot, making it final
---@param id IID
---@param slot integer
---@param size integer
function Inventory.Lock.commitRemove(id, slot, size)
  local current_removed = Inventory.Lock.remove_max[Helper.makeIndex(id, slot)]
  local new_size = Item.getsize(current_removed) - size
  if new_size < 0 then
    error("committing more than possible: Inventory.Lock.commitRemove(" .. id .. ", " .. slot .. ", " .. size .. ")")
  end
  if new_size == 0 then
    Inventory.Lock.remove_max[Helper.makeIndex(id, slot)] = nil
  else
    Item.setsize(current_removed, new_size)
  end
  Inventory.changeSingle(id, current_removed, slot, -size)
end

--- starts adding an item to the slot.
---@param id IID
---@param item Item
---@param slot (nil | integer)
---@param size (nil | integer)
---@return boolean success
function Inventory.Lock.startAdd(id, item, slot, size, precalculated_can)
  -- todo: need to actually order a drone
  slot = slot or Item.getslot(item)
  size = size or Item.getsize(item)
  return Inventory.Lock.add_add_max(id, slot, size, item, precalculated_can)

end

--- starts removing an item from the slot.
---@param id IID
---@param item Item
---@param slot (nil | integer)
---@param size (nil | integer)
---@return boolean success
function Inventory.Lock.startRemove(id, item, slot, size, precalculated_can)
  slot = slot or Item.getslot(item)
  size = size or Item.getsize(item)
  return Inventory.Lock.add_remove_max(id, slot, size, item, precalculated_can)

end

--- sets the inventory according to scan data
-- todo: this currently changes data asynchronously.
-- todo: currently does not support from and to. as such, those themselves are disabled.
-- scan_data = {id=?,time_start=?,time_end=?,space=?,from=?,to=?,storage={[?]={...Item...}}}
local function updateFromScan(scan_data)
  Inventory.write(scan_data.id, Helper.mapWithKeys(scan_data.storage, Item.parseScanned), scan_data.space)
end

-- automatically update inventories when scan data arrives
local function scan_data_listener(e, localAddress, remoteAddress, port, distance, name, message)
  if name ~= "scan_data" then
    return
  end
  local scan_data = serialization.unserialize(message)
  updateFromScan(scan_data)
end

local function startListening()
  return longmsg.listen(scan_data_listener)
end
local cancelvalue = startListening()

local function quit()
  event.cancel(cancelvalue)
  Inventory.saveInventories()
end

return Inventory
