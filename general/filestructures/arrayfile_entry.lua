local Helper = require "Helper"
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
---@param keys keysArg
---@return any ...
function arrayfile_entry.unpackEntry(entry, keys)
    if not keys then
        return
    end
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

---passed to arrayfile_entry.entriesMightMatch. if contains _function, it is used to override entriesMightMatch.
---@class entrypattern: entry, nil, { _function: (fun(entry:entry?):boolean,boolean) }
---@field _function? (fun(self:entrypattern,entry:entry?):boolean,boolean)

---could pattern be a subset of entry (if there was more info)? symmetrical.
---also, is the current info about entry enough to say that it matches the pattern?
---@param pattern entrypattern
---@param entry entry?
---@return boolean might
---@return boolean will
function arrayfile_entry.entriesMightMatch(pattern, entry)
    if not pattern then
        return true, true
    end
    if not entry then
        return true, false
    end
    if pattern._function then
        return pattern._function(pattern, entry)
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

---splits a string by whitespace/punctuation
---if it's already split, do nothing and return it
---@param str keysArg
---@return string[]
---@overload fun(falsey:nil|false): nil|false
function arrayfile_entry.splitArgString(str)
    if not str then
        return str
    end
    if type(str) == "string" then
        return {Helper.splitString(str, "[%s%p]+", true)}
    else
        return str
    end
end

---entry must be a subset of otherEntry.
---return an entry that contains entry, but has less or equal holes
---for use in write, so that one does not need to seek.
---@param entry entry
---@param otherEntry entry?
---@return entry
function arrayfile_entry.entryHolesFilled(entry, otherEntry)
    if not otherEntry then
        return entry
    else
        return otherEntry -- todo: smarter.
    end
end

return arrayfile_entry
