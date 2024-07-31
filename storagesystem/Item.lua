local serialization = require "serialization"
local Helper = require "Helper"

local Item = {}

---@class Item: table
---@field slot integer
---@field size integer
---@field uitem UItem

---@class UItem: table
---@field name string
---@field damage integer
---@field label string
---@field hasTag boolean
---@field maxDamage integer
---@field maxSize integer
---@field hash string

--- gets what slot the item is in
---@param self Item
function Item.getslot(self)
  return self.slot
end
---@param self Item
function Item.getsize(self)
  return self.size
end

---@param self Item
---@return string
function Item.getname(self)
  return Item.getUItem(self)[1]
end
---@param self Item
---@return integer
function Item.getdamage(self)
  return Item.getUItem(self)[2]
end
---@param self Item
---@return string
function Item.getlabel(self)
  return Item.getUItem(self)[3]
end
---@param self Item
---@return boolean
function Item.gethasTag(self)
  return Item.getUItem(self)[4]
end
---@param self Item
---@return integer
function Item.getmaxDamage(self)
  return Item.getUItem(self)[5]
end
---@param self Item
---@return integer
function Item.getmaxSize(self)
  return Item.getUItem(self)[6]
end

---@param self Item
---@return string
function Item.getMod(self)
  local modname, name = Helper.splitString(Item.getname(self), ":")
  return modname
end

---@param item Item
---@param value integer
function Item.setsize(item, value)
  item.size = value
end

---@param self Item
---@return string
function Item.getHash(self)
  return Item.getUItem(self)[7]
end
--- gets uItem
---@param self Item
---@return UItem
function Item.getUItem(self)
  return self.uitem or self
  -- if type(item) == "string" then
  --   return error("unimplemented")
  -- end
end

--- whether the items are the same, excluding slot and size
---@param a Item|nil
---@param b Item|nil
---@return boolean
function Item.equals(a, b)
  return a and b and Item.makeIndex(a) == Item.makeIndex(b) or false
  -- return Item.getHash(a) == Item.getHash(b)
  -- if type(a) ~= "table" or type(b) ~= "table" then
  --   return false
  -- end
  -- for i = Item.nameIndex, Item.maxSizeIndex do
  --   if a[i] ~= b[i] then
  --     return false
  --   end
  -- end
  -- return true
end

--- get a copy of the Item. with overriden slot and size, possibly.
---@param self Item
---@param slot integer|nil
---@param size integer|nil
---@return Item
function Item.copy(self, slot, size)
  return {
    slot = slot or self.slot,
    size = size or self.size,
    uitem = Item.getUItem(self)
  }
  -- return {slot or self[1], size or self[2], self[3], self[4], self[5], self[6], self[7], self[8]}
end

--- makes a string that is same for all of the same type of item
---@param self Item
---@return string
function Item.makeIndex(self)
  return serialization.serialize(Item.getUItem(self))
  --   return Helper.makeIndexBetween(self, Item.name)
end

local function stripitemstr(item, slot)
  return item and
    "{" ..
      table.concat(
        {
          slot or 0,
          item.size,
          '"' .. item.name .. '"',
          item.damage,
          '"' .. item.label .. '"',
          item.hasTag and "true" or "false",
          item.maxDamage,
          item.maxSize
        },
        ","
      ) ..
        "}"
end
--- new version of stripitemstr in drones ver 0.1.1
---@param i table
---@param slot integer
local function stis(i, slot)
  local h = db and db.computeHash(1) or "nil"
  return i and
    "{" ..
      table.concat(
        {
          slot,
          i.size,
          '"' .. i.name .. '"',
          i.damage,
          '"' .. i.label .. '"',
          i.hasTag and "true" or "false",
          i.maxDamage,
          i.maxSize,
          '"' .. h .. '"'
        },
        ","
      ) ..
        "}"
end

---@param name string
---@param damage integer
---@param label string
---@param hasTag boolean
---@param maxDamage integer
---@param maxSize integer
---@param hash string
---@return UItem
function Item.uItem(name, damage, label, hasTag, maxDamage, maxSize, hash)
  return {name, damage, label, hasTag, maxDamage, maxSize, hash}
end

--- takes an entry generated by stis in a drone scan, and returns an Item and its slot
---@param scan_item table
---@return Item
---@return integer slot
function Item.parseScanned(scan_item, old_index)
  return {
    slot = scan_item[1],
    size = scan_item[2],
    uitem = Item.uItem(scan_item[3], scan_item[4], scan_item[5], scan_item[6], scan_item[7], scan_item[8], scan_item[9])
  }, scan_item[1]
end

return Item

--[[ 
representation of items:
slot=?,
iid=?, --- maybe?
size=?,
uitem = {hash, name, damage, label, hasTag, maxDamage, maxSize} or integer -- if integer, it's an index in a dictionary
]]
