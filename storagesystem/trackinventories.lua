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
---@alias Side integer

Inventory.Item = Item
Inventory.INVENTORIES_PATH = "/usr/storage/inventories.csv"
Inventory.FILENAME_START = "/usr/storage/invs/inv_"

---@class InventoryData
---@field id IID
---@field side Side
---@field space integer
---@field isExternal boolean
---@field sizeMultiplier number
---@field file string

-- {id=?, nodeparent=?, x=?, y=?, z=?, side=?, space=?, isExternal=?, sizeMultiplier=1, file="?/?.csv"}
---@type table<IID,InventoryData>
Inventory.inventories = filehelp.loadCSV(Inventory.INVENTORIES_PATH, "id")

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
    local contents =
      Helper.mapWithKeys(
      filehelp.loadf(file_path),
      function(v) -- todo: replace with filehelp.loadCSV
        local t = serialization.unserialize(v)
        if t then
          spacetaken = spacetaken + 1
          return t, Item.getslot(t)
        end
      end
    )
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
      -- todo: error
      error("amount changed to below 0")
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
---@param slot number
---@param size number
function Inventory.changeSingle(id, slot, item, size)
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

Inventory.Lock = require("Lock"):create(Inventory)

--- sets the inventory according to scan data
-- todo: this currently changes data asynchronously.
-- todo: currently does not support from and to. as such, those themselves are disabled.
-- scan_data = {id=?,time_start=?,time_end=?,space=?,from=?,to=?,storage={[?]={...Item...}}}
local function updateFromScan(scan_data)
  Inventory.write(scan_data.id, Helper.mapWithKeys(scan_data.storage, Item.parseScanned), scan_data.space)
end

-- todo: handle updating from scan in a Future.onSuccess?

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
