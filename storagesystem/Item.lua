-- slot, size, name, damage, label, hasTag, maxDamage, maxSize
local Item = {}

function Item.strip(inp, slot)
  return {slot or 0, inp.size, inp.name, inp.damage, inp.label, inp.hasTag, inp.maxDamage, inp.maxSize}
end
function Item.getslot(self)
  return self.slot
end
function Item.getsize(self)
  return self.size
end
function Item.getname(self)
  return Item.getUItem(self)[2]
end
function Item.getdamage(self)
  return Item.getUItem(self)[3]
end
function Item.getlabel(self)
  return Item.getUItem(self)[4]
end
function Item.gethasTag(self)
  return Item.getUItem(self)[5]
end
function Item.getmaxDamage(self)
  return Item.getUItem(self)[6]
end
function Item.getmaxSize(self)
  return Item.getUItem(self)[7]
end

Item.slotIndex = 1
Item.sizeIndex = 2
Item.nameIndex = 3
Item.damageIndex = 4
Item.labelIndex = 5
Item.hasTagIndex = 6
Item.maxDamageIndex = 7
Item.maxSizeIndex = 8

function Item.setsize(item, value)
  item.size = value
end

-- todo: Item and Itemstack separate
-- drone api hasn't changed though
-- old item type = WholeItem?
-- maybe should be named after all?

function Item.getHash(item)
  if type(item) == "string" then -- already a hash
    return item
  elseif item.uitem then -- itemstack
    return Item.getHash(item.uitem)
  else
    return item[1] -- uitem
  end
end
function Item.getUItem(self)
  return item.uitem or item
  -- if type(item) == "string" then
  --   return error("unimplemented")
  -- end

end

--- whether the items are the same, excluding slot and size
---@param a table|nil Item
---@param b table|nil Item
---@return boolean
function Item.equals(a, b)
  return Item.makeIndex(a) == Item.makeIndex(b)
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
---@param self table Item
---@param slot number|nil
---@param size number|nil
---@return table Item
function Item.copy(self, slot, size)
  return {
    slot = slot or self.slot,
    size = size or self.size,
    uitem = self.uitem
  }
  -- return {slot or self[1], size or self[2], self[3], self[4], self[5], self[6], self[7], self[8]}
end

--- makes a string that is same for all of the same type of item
---@param self table Item
---@return string
function Item.makeIndex(self)
  return serialization.serialize(Item.getUItem(self))
  --   return Helper.makeIndexBetween(self, Item.name)

end

local function stripitemstr(item, slot)
  return item and "{" ..
           table.concat({slot or 0, item.size, "\"" .. item.name .. "\"", item.damage, "\"" .. item.label .. "\"",
                         item.hasTag and "true" or "false", item.maxDamage, item.maxSize}, ",") .. "}"
end
local function stis(slot) -- new version of stripitemstr in drones with a db
  local i, h = db.get(1), db.computeHash(1)
  return i and "{" ..
           table.concat(
      {slot, i.size, "\"" .. i.name .. "\"", i.damage, "\"" .. i.label .. "\"", i.hasTag and "true" or "false",
       i.maxDamage, i.maxSize, h}, ",") .. "}"
end

function Item.uItem(hash, name, damage, label, hasTag, maxDamage, maxSize)
  return {hash, name, damage, label, hasTag, maxDamage, maxSize}
end

--- takes an entry generated by stripitemstr, and returns an Item and its slot
---@param scan_item table
---@return table Item
---@return integer slot
function Item.parseScanned(scan_item, old_index)
  return {
    slot = scan_item[1],
    size = scan_item[2],
    uitem = Item.uItem(scan_item[9], scan_item[3], scan_item[4], scan_item[5], scan_item[6], scan_item[7], scan_item[8])
  }, scan_item[1]
end

return Item

--[[ 
future representation of items:
slot=?,
iid=?,
size=?,
uitem = {hash, name, damage, label, hasTag, maxDamage, maxSize} or integer -- if integer, it's an index in a dictionary
]]
