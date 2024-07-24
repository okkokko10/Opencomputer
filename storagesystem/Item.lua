-- slot, size, name, damage, label, hasTag, maxDamage, maxSize
local Item = {}

function Item.strip(inp, slot)
  return {slot or 0, inp.size, inp.name, inp.damage, inp.label, inp.hasTag, inp.maxDamage, inp.maxSize}
end
function Item.getslot(self)
  return self[1]
end
function Item.getsize(self)
  return self[2]
end
function Item.getname(self)
  return self[3]
end
function Item.getdamage(self)
  return self[4]
end
function Item.getlabel(self)
  return self[5]
end
function Item.gethasTag(self)
  return self[6]
end
function Item.getmaxDamage(self)
  return self[7]
end
function Item.getmaxSize(self)
  return self[8]
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
  item[2] = value
end

-- todo: Item and Itemstack separate
-- drone api hasn't changed though
-- old item type = WholeItem?
-- maybe should be named after all?

--- whether the items are the same, excluding slot and size
---@param a table|nil Item
---@param b table|nil Item
---@return boolean
function Item.equals(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  for i = Item.nameIndex, Item.maxSizeIndex do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

--- get a copy of the Item. with overriden slot and size, possibly.
---@param self table Item
---@param slot number|nil
---@param size number|nil
---@return table Item
function Item.copy(self, slot, size)
  return {slot or self[1], size or self[2], self[3], self[4], self[5], self[6], self[7], self[8]}
end

-- makes a string that is same for all of the same type of item
function Item.makeIndex(self)
  return serialization.serialize(Item.copy(self, 0, 0))
  --   return Helper.makeIndexBetween(self, Item.name)

end

local function stripitemstr(item, slot)
  return item and "{" ..
           table.concat({slot or 0, item.size, "\"" .. item.name .. "\"", item.damage, "\"" .. item.label .. "\"",
                         item.hasTag and "true" or "false", item.maxDamage, item.maxSize}, ",") .. "}"
end

return Item
