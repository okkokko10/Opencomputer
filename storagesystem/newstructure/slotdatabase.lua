local cachedarrayfile = require("cachedarrayfile")


---@class slotdatabase
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
---@return integer|nil new_itemOut_bottomSlot
---@return integer new_itemIn_topSlot
function Slots:changeItem(index, itemIn_itemID, itemIn_topSlot, inAmount)
    local new_itemOut_topSlot
    local new_itemOut_bottomSlot
    local new_itemIn_topSlot

    local oldItem = self:readEntry(index, "next prev")
    local changes = {}
    self:assume(oldItem.prev, {next = index, itemID = oldItem.itemID})
    if oldItem.prev ~= 0 then
        assert(oldItem.prev ~= oldItem.next)
        changes[oldItem.prev] = {next = oldItem.next}
    else
        -- old item had no prev; it was the bottom. this means the new bottom is oldItem.next
        new_itemOut_bottomSlot = oldItem.next
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
    return new_itemOut_topSlot, new_itemOut_bottomSlot, new_itemIn_topSlot
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

---gets the first 4 bytes of metadata as a uint
---exclusive end
---@param arrf arrayfile
---@return integer
function slotdatabase.getSize(arrf)
    return select(1, string.unpack("I4", arrf:readMetadata()))
end

---sets the first 4 bytes of metadata as a uint
---@param arrf arrayfile
---@param size integer
function slotdatabase.setSize(arrf, size)
    string.gsub(arrf:readMetadata(), "^....", string.pack("I4", size), 1)
end

local ItemData = cachedarrayfile.make("/usr/storage/itemData.arrayfile", "amount: I4, top: I3, bottom: I3, info: I4, stacksize: I1")

slotdatabase.Slots = Slots
slotdatabase.ItemData = ItemData

---todo: a branch of the database, with its own writes that can be commited or rolled back.
---@class Transaction
---@field database slotdatabase
---@field suppressor1  { finish:  fun() }
---@field suppressor2  { finish:  fun() }
local Transaction = {}
function Transaction:commit()

    --- temporary:
    self.suppressor1:finish()
    self.suppressor2:finish()
    -- todo: unimplemented.
    return self.database
end
function Transaction:rollback()
    -- todo: unimplemented
    return self.database
end

---creates a Transaction.
---@param database slotdatabase
---@return slotdatabase|Transaction
function Transaction.create(database)
    local tr = setmetatable({database=database,commit=Transaction.commit,rollback=Transaction.rollback},{__index = database})
    
    --temporary. doesn't even work properly, since it also takes old flushes
    tr.suppressor1 = database.Slots:suppressFlush()
    tr.suppressor2 = database.ItemData:suppressFlush()
    

    return tr
end


function slotdatabase:beginTransaction()
    return Transaction.create(self)
end

---todo: give abstract orders that ask to use a value that is fetched later.
---todo: slots that have 0 of an item are converted to air if they are also the top.

---changes the item at slot index from out_itemID to in_itemID (with amount amount)
---does not update the total amounts
---@param index integer
---@param in_itemID integer
---@param out_itemID integer
---@param amount integer
function slotdatabase:changeItem(index, in_itemID, out_itemID, amount)
    local newItem = self.ItemData:readEntry(in_itemID, "top bottom")
    local out_top, out_bottom, in_top = self.Slots:changeItem(index, in_itemID, newItem.top, amount)
    self.ItemData:writeEntry(in_itemID, {top = in_top, bottom = (newItem.bottom == 0) and in_top or nil})
    self.ItemData:writeEntry(out_itemID, {top = out_top, bottom = out_bottom})
end

---updates the item data at the slot accordingly. Handles updating total item amounts.
---Updating from a scan can be done by setting each item with this.
---Setting an item that exists in that slot (once items have finished moving around (todo: needs more consideration)) is valid.
---@param index integer
---@param itemID integer
---@param amount integer
function slotdatabase:setItem(index, itemID, amount)
    local oldSlot = self.Slots:readEntry(index,"itemID amount")
    local old_itemID = oldSlot.itemID
    local old_amount = oldSlot.amount
    if itemID == old_itemID then
        self.Slots:writeEntry(index,{amount=amount})
        local old_new_total_amount = self.ItemData:readEntry(itemID, "amount").amount
        self.ItemData:writeEntry(itemID,{amount = old_new_total_amount + amount - old_amount})
    else
        local old_total_amounts = self.ItemData:readEntries({
            [itemID] = "amount",
            [old_itemID] = "amount"
        })
        local old_new_total_amount = old_total_amounts[itemID].amount
        local old_old_total_amount = old_total_amounts[old_itemID].amount
        self:changeItem(index,itemID,old_itemID,amount)
        self.ItemData:writeEntries({
            [itemID] = {amount = old_new_total_amount + amount},
            [old_itemID] = {amount = old_old_total_amount - old_amount}
        })
    end
end


function slotdatabase:flush()
    self.ItemData:flushWrites(true)
    self.Slots:flushWrites(true)
end

---adds a new item.
---@param infoPosition integer
---@return integer itemID
function slotdatabase:addNewItem(infoPosition)
    local size = self.getSize(self.ItemData)
    self.ItemData:writeEntry(size, {amount = 0, top = 0, bottom = 0, infoPosition = infoPosition})
    self.setSize(self.ItemData, size + 1)
    return size
end

---adds new slots filled with air_itemID. these will be filled last. air's bottom is larger, unlike normal.
---@param containerID integer
---@param air_itemID integer
---@param count integer
---@return integer start -- inclusive
---@return integer finish -- inclusive
function slotdatabase:addSlots(containerID, air_itemID, count)
    assert(count > 0, "container must have positive size")
    local size = self.getSize(self.Slots)
    local start = size
    local air = self.ItemData:readEntry(air_itemID, "amount bottom")
    self.Slots:writeEntry(air.bottom, {prev = size})
    local nex = air.bottom
    for i = 1, count do
        self.Slots:writeEntry(
            size,
            {
                itemID = air_itemID,
                amount = 1,
                next = nex,
                prev = size + 1,
                containerHash = containerID % 256
            }
        )
        nex = size
        size = size + 1
    end
    self.Slots:writeEntry(nex, {prev = 0}) -- undo last for loop's prev
    local newAir = {bottom = nex, amount = air.amount + count}
    if air.bottom == 0 then
        newAir.top = start
    end
    self.ItemData:writeEntry(air_itemID, newAir)
    self.setSize(self.Slots, size)
    return start, size - 1
end

return slotdatabase
