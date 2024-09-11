local cachedarrayfile = require("cachedarrayfile")
local Database = require("Database")
local CachedDataFile = require("CachedDataFile")
local AppendStringListFile = require("AppendStringListFile")

---@class slotdatabase: Database
local slotdatabase = setmetatable({}, Database)

---@class Slots: cachedarrayfile
local Slots =
    cachedarrayfile.make(
    "/usr/storage/slots.arrayfile",
    "itemID: I3, amount: I4, next: I3, prev: I3, containerHash: I2"
)
Slots.assume_behaviour = {check = true}

local ItemData =
    cachedarrayfile.make(
    "/usr/storage/itemData.arrayfile", --
    "amount: I4, top: I3, bottom: I3, info: I4, stacksize: I1"
)

--- used to search for items.
local ItemHashes =
    cachedarrayfile.make(
    "/usr/storage/itemHashes.arrayfile",
    "modIDhash: I1, nameLetters I1, charSum I1, meta I1, labelLetters I1 dataHash I1"
)

local FullUniqueItem = CachedDataFile.make(AppendStringListFile.make("/usr/storage/uniqueitems.listfile"))

-- local SlotLock = SparseDataFile
local Containers =
    cachedarrayfile.make(
    "/usr/storage/containers.arrayfile",
    "nodeparent: I2, x: i4, y: i4, z: i4, side: I1, isExternal: B, sizeMultiplier: I4, airID: I3, start: I3, stop: I3"
) -- stop is exclusive

local Nodes = cachedarrayfile.make("/usr/storage/nodes.arrayfile", "nodeparent: I2, x: i4, y: i4, z: i4")

-- local Mods = CachedDataFile.make(AppendStringListFile.make("/usr/storage/mods.listfile"), math.huge, math.huge)
local Mods = cachedarrayfile.make("/usr/storage/mods.arrayfile", "modname: c20")
---modname limited to 20 characters
---@param modname string
---@return string
function slotdatabase:formatModname(modname)
    if #modname > 20 then
        modname = string.sub(modname, 1, 10) .. string.sub(modname, -10, -1)
    end
    return string.pack("c20", modname)
end

slotdatabase.datafiles = {
    Slots = Slots,
    ItemData = ItemData,
    ItemHashes = ItemHashes,
    Mods = Mods,
    FullUniqueItem = FullUniqueItem,
    Containers = Containers
}

---overwrite the entry at index, setting its itemID and amount, and making it the new topSlot
---@param index integer
---@param itemIn_itemID integer
---@param itemIn_topSlot integer
---@param inAmount integer
---@return integer|nil new_itemOut_topSlot
---@return integer|nil new_itemOut_bottomSlot
---@return integer new_itemIn_topSlot
---@return integer itemOut_itemID
function Slots:changeItem(index, itemIn_itemID, itemIn_topSlot, inAmount)
    local new_itemOut_topSlot
    local new_itemOut_bottomSlot
    local new_itemIn_topSlot
    local itemOut_itemID

    local oldItem = self:readEntry(index, "next prev itemID")
    itemOut_itemID = oldItem.itemID
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
    return new_itemOut_topSlot, new_itemOut_bottomSlot, new_itemIn_topSlot, itemOut_itemID
end

--#region eventual

local eventual = require("eventual")

---overwrite the entry at index, setting its itemID and amount, and making it the new topSlot
---@param index integer|EventualValue
---@param itemIn_itemID integer|EventualValue
---@param itemIn_topSlot integer|EventualValue
---@param inAmount integer|EventualValue
---@return integer|nil|EventualValue new_itemOut_topSlot
---@return integer|nil|EventualValue new_itemOut_bottomSlot
---@return integer|EventualValue new_itemIn_topSlot
function Slots:changeItemEventual(index, itemIn_itemID, itemIn_topSlot, inAmount)
    local new_itemOut_topSlot
    local new_itemOut_bottomSlot
    local new_itemIn_topSlot

    local oldItem = eventual.wrap(self):readEntry(index, "next prev")

    eventual.wrap(self):assume(oldItem.prev, {next = index, itemID = oldItem.itemID})

    local cond = eventual.neq(oldItem.prev, 0)
    eventual.IF(cond)
    eventual.assert(eventual.neq(oldItem.prev, oldItem.next))
    eventual.wrap(self):writeEntry(oldItem.prev, {next = oldItem.next})
    eventual.END()
    -- old item had no prev; it was the bottom. this means the new bottom is oldItem.next

    new_itemOut_bottomSlot = eventual.choose(cond, nil, oldItem.next)

    local cond2 = eventual.eq(oldItem.next, 0)
    new_itemOut_topSlot = eventual.choose(cond2, oldItem.prev, nil)
    eventual.IF(cond2)
    -- means index == itemOut.topSlot
    eventual.ELSE()
    eventual.wrap(self):assume(oldItem.next, {prev = index, itemID = oldItem.itemID})
    eventual.wrap(self):writeEntry(oldItem.next, {prev = oldItem.prev})
    eventual.END()
    -- new item in. put it at the top of its linked list
    eventual.wrap(self):writeEntry(index, {prev = itemIn_topSlot, next = 0, itemID = itemIn_itemID, amount = inAmount})
    eventual.IF(eventual.neq(itemIn_topSlot, 0))
    eventual.wrap(self):assume(itemIn_topSlot, {itemID = itemIn_itemID, next = 0})
    eventual.wrap(self):writeEntry(itemIn_topSlot, {next = index})
    eventual.END()

    new_itemIn_topSlot = index
    return new_itemOut_topSlot, new_itemOut_bottomSlot, new_itemIn_topSlot
end
--#endregion eventual

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
---@param arrf GenericDataFile
---@return integer
function slotdatabase.getSize(arrf)
    return select(1, string.unpack("I4", arrf:readMetadata()))
end

---sets the first 4 bytes of metadata as a uint
---@param arrf GenericDataFile
---@param size integer
function slotdatabase.setSize(arrf, size)
    string.gsub(arrf:readMetadata(), "^....", string.pack("I4", size), 1)
end

---adds a new entry to the end of datafile, and returns its index
---@param datafile GenericDataFile
---@param entry table
---@return integer
function slotdatabase.addEntryToEnd(datafile, entry)
    local size = slotdatabase.getSize(datafile)
    datafile:writeEntry(size, entry)
    slotdatabase.setSize(datafile, datafile:next(size, entry))
    return size
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
    local newItem = self.datafiles.ItemData:readEntry(in_itemID, "top bottom")
    local out_top, out_bottom, in_top, out_itemID =
        Slots.changeItem(self.datafiles.Slots, index, in_itemID, newItem.top, amount)
    self.datafiles.ItemData:writeEntry(in_itemID, {top = in_top, bottom = (newItem.bottom == 0) and in_top or nil})
    self.datafiles.ItemData:writeEntry(out_itemID, {top = out_top, bottom = out_bottom})
end

---updates the item data at the slot accordingly. Handles updating total item amounts.
---Updating from a scan can be done by setting each item with this.
---Setting an item that exists in that slot (once items have finished moving around (todo: needs more consideration)) is valid.
---@param index integer
---@param itemID integer
---@param amount integer
function slotdatabase:setItem(index, itemID, amount)
    local oldSlot = self.datafiles.Slots:readEntry(index, "itemID amount")
    local old_itemID = oldSlot.itemID
    local old_amount = oldSlot.amount
    if itemID == old_itemID then
        self.datafiles.Slots:writeEntry(index, {amount = amount})
        local old_new_total_amount = self.datafiles.ItemData:readEntry(itemID, "amount").amount
        self.datafiles.ItemData:writeEntry(itemID, {amount = old_new_total_amount + amount - old_amount})
    else
        local old_total_amounts =
            self.datafiles.ItemData:readEntries(
            {
                [itemID] = "amount",
                [old_itemID] = "amount"
            }
        )
        local old_new_total_amount = old_total_amounts[itemID].amount
        local old_old_total_amount = old_total_amounts[old_itemID].amount
        self:changeItem(index, itemID, old_itemID, amount)
        self.datafiles.ItemData:writeEntries(
            {
                [itemID] = {amount = old_new_total_amount + amount},
                [old_itemID] = {amount = old_old_total_amount - old_amount}
            }
        )
    end
end

function slotdatabase:flush()
    for _, datafile in pairs(self.datafiles) do
        datafile:flushWrites(true)
    end
end

---adds a new item.
---@param infoPosition integer
---@return integer itemID
function slotdatabase:addNewItemData(infoPosition, stacksize)
    local size = self.getSize(self.datafiles.ItemData)
    self.datafiles.ItemData:writeEntry(
        size,
        {amount = 0, top = 0, bottom = 0, info = infoPosition, stacksize = stacksize}
    )
    self.setSize(self.datafiles.ItemData, size + 1)
    return size
end
---makes an item hash at the index.
---@param item Item -- todo
---@param index integer
function slotdatabase:addNewItemHash(item, index)
    self.datafiles.ItemHashes:writeEntry(index, self:makeItemHash(item))
end

---adds new slots filled with air_itemID. these will be filled last. air's bottom is larger, unlike normal.
---@param containerID integer
---@param air_itemID integer
---@param count integer
---@return integer start -- inclusive
---@return integer stop -- exclusive
function slotdatabase:addSlots(containerID, air_itemID, count)
    assert(count > 0, "container must have positive size")
    local size = self.getSize(self.datafiles.Slots)
    local start = size
    local air = self.datafiles.ItemData:readEntry(air_itemID, "amount bottom")
    self.datafiles.Slots:writeEntry(air.bottom, {prev = size})
    local nex = air.bottom
    for i = 1, count do
        self.datafiles.Slots:writeEntry(
            size,
            {
                itemID = air_itemID,
                amount = 1,
                next = nex,
                prev = size + 1,
                containerHash = containerID & 0xFFFF
            }
        )
        nex = size
        size = size + 1
    end
    self.datafiles.Slots:writeEntry(nex, {prev = 0}) -- undo last for loop's prev
    local newAir = {bottom = nex, amount = air.amount + count}
    if air.bottom == 0 then
        newAir.top = start
    end
    self.datafiles.ItemData:writeEntry(air_itemID, newAir)
    self.setSize(self.datafiles.Slots, size)
    return start, size
end

---adds a new modname to the end of Mods, and returns its position
---@param modname any
---@return integer
function slotdatabase:addMod(modname)
    return self.addEntryToEnd(self.datafiles.Mods, {modname = modname})
end

--#region makeItemHash

---gets the id for the modname. if the modname hasn't been encountered yet, add it.
---@param modname string
---@return integer
function slotdatabase:getModId(modname)
    modname = self:formatModname(modname)
    local entry, index = self.datafiles.Mods:find({modname = modname}, 0, self.getSize(self.datafiles.Mods))
    if index then
        return index
    else
        return self:addMod(modname)
    end
end

local letterBitmask = require("letterBitmask")

-- "modIDhash: I1, nameLetters I1, charSum I1, meta I1, labelLetters I1 dataHash I1"
function slotdatabase:make_ItemHashes_modIDhash(item)
    if item.modname then
        return self:getModId(item.modname) & 0xFF
    end
end
function slotdatabase:make_ItemHashes_nameLetters(item)
    if item.name then
        return letterBitmask.make(item.name) & 0xFF
    end
end
function slotdatabase:make_ItemHashes_charSum(item)
    if item.name then
        return letterBitmask.charSum(item.name) & 0xFF
    end
end
function slotdatabase:make_ItemHashes_meta(item)
    if item.meta then
        return item.meta & 0xFF
    end
end
function slotdatabase:make_ItemHashes_labelLetters(item)
    if item.label then
        return letterBitmask.make(item.label) & 0xFF
    end
end
function slotdatabase:make_ItemHashes_dataHash(item)
    if item.hash then
        return tonumber(string.sub(item.hash, 1, 2), 16) & 0xFF
    else
        return nil
    end
end

---makes an ItemHashes entry from an item.
---@param item Item
function slotdatabase:makeItemHash(item)
    return {
        modIDhash = self:make_ItemHashes_modIDhash(item),
        nameLetters = self:make_ItemHashes_nameLetters(item),
        charSum = self:make_ItemHashes_charSum(item),
        meta = self:make_ItemHashes_meta(item),
        labelLetters = self:make_ItemHashes_labelLetters(item),
        dataHash = self:make_ItemHashes_dataHash(item)
    }
end

--#endregion

---adds a new unique item
---@param item Item
---@return integer itemID
function slotdatabase:addNewItem(item)
    local infoPosition = self.addEntryToEnd(self.datafiles.FullUniqueItem, {text = item:makeRepresentation()})
    local itemID = self:addNewItemData(infoPosition, item.stacksize)
    self:addNewItemHash(item, itemID)
    return itemID
end

---finds the itemID of an item.
---makeNew: if the item cannot be found, entries will be created for it.
---@param item Item
---@param fromExclusive integer?
---@param makeNew boolean?
---@return integer? itemID
---@return entry? itemData
---@return string? itemRepr
function slotdatabase:findItem(item, fromExclusive, makeNew)
    local itemHash = self:makeItemHash(item)
    local hashCount = self.getSize(self.datafiles.ItemHashes)
    ---@type integer?
    local itemID = fromExclusive and self.datafiles.ItemHashes:next(fromExclusive) or 0
    while itemID do
        _, itemID = self.datafiles.ItemHashes:find(itemHash, itemID, hashCount - 1)
        if itemID then
            local data = self.datafiles.ItemData:readEntry(itemID) --, {"info"})
            local itemRepr = self.datafiles.FullUniqueItem:readEntry(data.info).text
            if item:matchesRepresentation(itemRepr) then
                return itemID, data, itemRepr
            else
                itemID = self.datafiles.ItemHashes:next(itemID)
            end
        end
    end
    if makeNew then
        itemID = self:addNewItem(item)
        local data = self.datafiles.ItemData:readEntry(itemID)
        local itemRepr = self.datafiles.FullUniqueItem:readEntry(data.info).text
        return itemID, data, itemRepr
    end
end

---searches items. label can be partially written.
---@param label string
---@param modID integer?
---@param fromExclusive integer?
---@param to integer?
function slotdatabase:searchItem(label, modID, fromExclusive, to)
    local bitmask = letterBitmask.make(label)
    local pattern = {
        _function = function(patt, entry)
            local will = true
            if entry.labelLetters then
                if not letterBitmask.couldBeSubstring(entry.labelLetters, bitmask) then
                    return false, false
                end
            else
                will = false
            end
            if modID then
                if entry.modIDhash then
                    if entry.modIDhash ~= modID then
                        return false, false
                    end
                else
                    will = false
                end
            end
            return true, will
        end
    }
    local hashCount = self.getSize(self.datafiles.ItemHashes) -- todo: could this slow things down?
    ---@type integer?
    local itemID = fromExclusive and self.datafiles.ItemHashes:next(fromExclusive) or 0
    while itemID do
        _, itemID = self.datafiles.ItemHashes:find(pattern, itemID, hashCount - 1)
        if itemID then
            local data = self.datafiles.ItemData:readEntry(itemID) --, {"info"})
            local itemRepr = self.datafiles.FullUniqueItem:readEntry(data.info).text
            if Item2.representationMatchesLabel(itemRepr, label) then
                return itemID, data, itemRepr
            else
                itemID = self.datafiles.ItemHashes:next(itemID)
            end
        end
    end
end

--"nodeparent: I2, x: i4, y: i4, z: i4, side: I1, isExternal: B, sizeMultiplier: I4, airID: I3, start: I3, stop: I3"
function slotdatabase:addContainer(airID, size, nodeparent, x, y, z, side, isExternal, sizeMultiplier)
    local containerID =
        self.addEntryToEnd(
        self.datafiles.Containers,
        {
            nodeparent = nodeparent,
            x = math.floor(x),
            y = math.floor(y),
            z = math.floor(z),
            side = side,
            isExternal = isExternal and 1 or 0,
            sizeMultiplier = sizeMultiplier,
            airID = airID
        }
    )
    local start, stop = self:addSlots(containerID, airID, size)
    self.datafiles.Containers:writeEntry(containerID, {start = start, stop = stop})
    return containerID
end

return slotdatabase
