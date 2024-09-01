local cachedarrayfile = require("cachedarrayfile")

local slotdatabase = {}

---@class Slots: cachedarrayfile
local Slots =
    cachedarrayfile.make(
    "/usr/storage/slots.arrayfile",
    "itemID: I3, amount: I4, next: I3, prev: I3, containerHash: I1"
)
Slots.assume_behaviour = true

---overwrite the entry at index, setting its itemID and amount, and making it the new topSlot
---@param index integer
---@param itemIn_itemID integer
---@param itemIn_topSlot integer
---@param inAmount integer
---@return integer|nil new_itemOut_topSlot
---@return integer new_itemIn_topSlot
function Slots:changeItem(index, itemIn_itemID, itemIn_topSlot, inAmount)
    local new_itemOut_topSlot
    local new_itemIn_topSlot

    local oldItem = self:readEntry(index, "next prev")
    local changes = {}
    self:assume(oldItem.prev, {next = index, itemID = oldItem.itemID})
    if oldItem.prev ~= 0 then
        assert(oldItem.prev ~= oldItem.next)
        changes[oldItem.prev] = {next = oldItem.next}
    end
    if oldItem.next == 0 then -- means index == itemOut.topSlot
        new_itemOut_topSlot = oldItem.prev
    else
        self:assume(oldItem.next, {prev = index, itemID = oldItem.itemID})
        changes[oldItem.next] = {prev = oldItem.prev}
    end
    -- new item in. put it at the top of its linked list
    changes[index] = {prev = itemIn_topSlot, next = 0, itemID = itemIn_itemID, amount = inAmount}
    if itemIn_topSlot ~= 0 then
        self:assume(itemIn_topSlot, {itemID = itemIn_itemID, next = 0})
        changes[itemIn_topSlot] = {next = index}
    end
    self:writeEntries(changes)

    new_itemIn_topSlot = index
    return new_itemOut_topSlot, new_itemIn_topSlot
end

function Slots:checkAssertion(index)
    if index == 0 then
        return
    end
    local slot = self:readEntries({[index] = "itemID next"})[index]

    if slot.next ~= 0 then
        local nex = self:readEntries({[slot.next] = "itemID prev"})[slot.next]
        assert(nex.prev == index)
        assert(nex.itemID == slot.itemID)
    else
        -- assert(getTopSlot(slot.itemID) == index)
    end
end

local ItemData = cachedarrayfile.make("/usr/storage/itemData.arrayfile", "amount: I4, top: I3")

slotdatabase.Slots = Slots
slotdatabase.ItemData = ItemData

---changes the item at slot index from out_itemID to in_itemID (with amount amount)
---does not update the total amounts
---@param index integer
---@param in_itemID integer
---@param out_itemID integer
---@param amount integer
function slotdatabase:changeItem(index, in_itemID, out_itemID, amount)
    local newItem = self.ItemData:readEntry(in_itemID, "top")
    local out_top, in_top = self.Slots:changeItem(index, in_itemID, newItem.top, amount)
    self.ItemData:writeEntry(in_itemID, {top = in_top})
    self.ItemData:writeEntry(out_itemID, {top = out_top})
end

function slotdatabase:flush()
    self.ItemData:flushWrites(true)
    self.Slots:flushWrites(true)
end

return slotdatabase
