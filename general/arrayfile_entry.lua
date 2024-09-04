local arrayfile_entry = {}

function arrayfile_entry.makeEntryMetatable(arrf)
    return {
        __index = function(entry, key)
            return rawget(
                entry,
                arrf.nameIndex[key] or
                    error(
                        'no such key: "' ..
                            key ..
                                '" in arrayfile "' ..
                                    arrf.filename .. '". valid keys: ' .. table.concat(arrf.nameList, " ")
                    )
            )
        end,
        --- todo: this might be better to not enable? it should be immutable
        __newindex = function(entry, key, value)
            rawset(
                entry,
                arrf.nameIndex[key] or
                    error(
                        'no such key: "' ..
                            key ..
                                '" in arrayfile "' ..
                                    arrf.filename .. '". valid keys: ' .. table.concat(arrf.nameList, " ")
                    ),
                value
            )
        end,
        __pairs = function(entry)
            local i = 0
            local nex = function(ent, key)
                local out
                repeat
                    i = i + 1
                    out = rawget(ent, i)
                until out ~= nil or i > #arrf.nameList
                return arrf.nameList[i], out
            end
            return nex, entry
        end,
        parent = arrf
    }
end

---unpacks the entry with the given keys
---@param entry entry
---@param keys string[]
---@return any ...
function arrayfile_entry.unpackEntry(entry, keys)
    local unpacked = {}
    for i = 1, #keys do
        unpacked[i] = entry[keys[i]]
    end
    return table.unpack(unpacked, 1, #keys)
end

---makes an empty entry with the same index and metatable as model
---@param model entry
---@return entry
function arrayfile_entry.makeEntryWithEntry(model)
    return setmetatable({_i = model._i}, getmetatable(model))
end
---updates targetEntry with values in newValues
---@param targetEntry entry
---@param newValues entry?
---@private -- only used in updatedEntry
function arrayfile_entry.updateEntry(targetEntry, newValues)
    for i, value in pairs(newValues or {}) do -- this works whether or not entry has entryMetatable
        -- self.entryMetatable.__newindex(original, i, value)
        targetEntry[i] = value
    end
end
---like updateEntry, but not in place.
---@param targetEntry entry?
---@param newValues entry?
---@return entry?
function arrayfile_entry.updatedEntry(targetEntry, newValues)
    if not (targetEntry or newValues) then
        return nil
    end
    local new = arrayfile_entry.makeEntryWithEntry(targetEntry or newValues --[[@as entry --not nil]])
    arrayfile_entry.updateEntry(new, targetEntry)
    arrayfile_entry.updateEntry(new, newValues)
    return new
end

---checks whether the entry has all the described keys
---@param entry entry
---@param keys string[]
function arrayfile_entry.entryHasKeys(entry, keys)
    for i = 1, #keys do
        if entry[keys[i]] == nil then
            return false
        end
    end
    return true
end

---could pattern be a subset of entry (if there was more info)? symmetrical.
---also, is the current info about entry enough to say that it matches the pattern?
---@param entry entry?
---@param pattern entry?
---@return boolean might
---@return boolean will
function arrayfile_entry.entriesMightMatch(entry, pattern)
    if not pattern then
        return true, true
    end
    if not entry then
        return true, false
    end
    local every = true
    for i, value in pairs(pattern) do
        local a1 = entry[i]
        if a1 then
            if a1 ~= value then
                return false, false
            end
        else
            every = false
        end
    end
    return true, every
end
---entry with keys common with remove removed
---@param entry entry?
---@param remove entry?
---@return entry?
function arrayfile_entry.entrySetMinus(entry, remove)
    if not entry then
        return nil
    end
    if not remove then
        return entry
    end

    local new = arrayfile_entry.makeEntryWithEntry(entry)
    for i, value in pairs(entry) do
        if not remove[i] then
            new[i] = value
        end
    end
    return new
end

---updates targetEntry with values in newValues, but an existing value must be the same or it causes an error
---@param targetEntry entry
---@param newValues entry
function arrayfile_entry.updateEntrySubsetCheck(targetEntry, newValues)
    for i, value in pairs(newValues) do -- this works whether or not newValues has entryMetatable
        -- self.entryMetatable.__newindex(original, i, value)
        local old = targetEntry[i]
        if old then
            assert(value == old, "new value didn't match up with old value")
        else
            targetEntry[i] = value
        end
    end
end

return arrayfile_entry
