local Inventory = require("trackinventories")

local Helper = require "Helper"
local Item = require "Item"

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

---how much item can be removed from this slot?
---@param iid IID
---@param slot integer
---@param current_item Item? -- precalculate Inventory.getInSlot(iid, slot)
---@return integer
function Inventory.Lock.sizeRemovable(iid, slot, current_item)
    current_item = current_item or Inventory.getInSlot(iid, slot)

    if not current_item then
        error("no item compared")
    end

    local current_removed = Inventory.Lock.remove_max[Helper.makeIndex(iid, slot)]

    local current_removed_size = current_removed and Item.getsize(current_removed) or 0

    local current_size = Item.getsize(current_item)

    local maxRemovable = current_size - current_removed_size

    return maxRemovable
end

---how much item can be added to this slot?
---@param iid IID
---@param slot integer
---@param current_item Item? -- precalculate Inventory.getInSlot(iid, slot)
---@return integer
function Inventory.Lock.sizeAddable(iid, slot, current_item)
    current_item = current_item or Inventory.getInSlot(iid, slot) -- todo: current_item can be nil

    if not current_item then
        error("no item compared")
    end

    local current_size = current_item and Item.getsize(current_item) or 0

    ---@type Item
    local current_added = Inventory.Lock.add_max[Helper.makeIndex(iid, slot)]

    local current_added_size = current_added and Item.getsize(current_added) or 0

    local sizeMult = Inventory.getSizeMultiplier(iid)
    local maxAddable = Item.getmaxSize(current_item) * sizeMult - current_size - current_added_size
    return maxAddable
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
        error(
            "committing more than possible: Inventory.Lock.commitRemove(" .. id .. ", " .. slot .. ", " .. size .. ")"
        )
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
---@param slot integer
---@param size integer
---@return boolean success
function Inventory.Lock.startAdd(id, slot, size, item, precalculated_can)
    return Inventory.Lock.add_add_max(id, slot, size, item, precalculated_can)
end

--- starts removing an item from the slot.
---@param id IID
---@param item Item
---@param slot integer
---@param size integer
---@return boolean success
function Inventory.Lock.startRemove(id, slot, size, item, precalculated_can)
    return Inventory.Lock.add_remove_max(id, slot, size, item, precalculated_can)
end

return Inventory.Lock
