local arrayfile_entry = require "arrayfile_entry"
local Helper = require "Helper"

---@class GenericDataFile
local GenericDataFile = {}

GenericDataFile.__index = GenericDataFile

---@alias keysArg nil|false|string|string[] | "!"

--#region abstract

---readEntry, it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys keysArg
---@return entry entry
function GenericDataFile:readEntry(index, keys)
    error("unimplemented")
end

---returns the position of the entry after this one
---@param index integer
---@param entry entry?
---@return integer
function GenericDataFile:next(index, entry)
    error("unimplemented")
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function GenericDataFile:writeEntry(index, entry)
    error("unimplemented")
end

---get a cached entry, if caching exists. otherwise get nothing
---@param index integer
---@return entry?
function GenericDataFile:getCached(index)
    return nil -- default
end

function GenericDataFile:closeRead()
    -- default
end
function GenericDataFile:closeWrite()
    -- default
end

---@return table<string,integer|string> -- from external to internal entry key names
function GenericDataFile:getNameIndex()
    ---@diagnostic disable-next-line: undefined-field
    return self.nameIndex or error()
end

---@return string[] -- list of entry key names
function GenericDataFile:getNameList()
    ---@diagnostic disable-next-line: undefined-field
    return self.nameList or error()
end
---@return integer
function GenericDataFile:getMetadataSize()
    ---@diagnostic disable-next-line: undefined-field
    return self.metadataSize or error()
end

--#endregion abstract

function GenericDataFile:close()
    self:closeRead()
    self:closeWrite()
end

---readEntryValues, but additionally returns its values in the order given in keys
---@param index integer
---@param keys keysArg
---@return entry entry
---@return ... any -- values corresponding to keys
function GenericDataFile:readEntryFancy(index, keys)
    keys = arrayfile_entry.splitArgString(keys)
    local entry = self:readEntry(index, keys)
    return entry, arrayfile_entry.unpackEntry(entry, keys)
end

---do multiple readEntryValues at once.
---proper way to query values.
--- {[3]="a b c",[5]="d c"} => {[3]={a=?,b=?,c=?},[5]={d=?,c=?}}
---@param indices_keys table<integer,true|string|string[]>
---@return table<integer,entry> indices_entries
function GenericDataFile:readEntries(indices_keys)
    local indices_entries = {}
    for index, keys in Helper.sortedpairs(indices_keys) do
        indices_entries[index] = self:readEntry(index, keys)
    end
    return indices_entries
end

---calls self:writeEntry(index,value) on all index-value pairs, in ascending order.
---writes entries. in a sense updates this with indices_entries.
---nil keeps old value
---@param indices_entries table<integer,table>
function GenericDataFile:writeEntries(indices_entries)
    for index, entry in Helper.sortedpairs(indices_entries) do
        self:writeEntry(index, entry)
    end
end

---gets the metadata string, of length `self.metadataSize`
---@return string
function GenericDataFile:readMetadata()
    return self:readEntry(-math.huge).metadata
end

---writes metadata
---@param string string
---@return nil
function GenericDataFile:writeMetadata(string)
    local metadataSize = self:getMetadataSize()
    local metadata = string.sub(string, 1, metadataSize)
    local padding = metadataSize - #metadata
    if padding > 0 then
        metadata = metadata .. string.rep("\0", padding - 1) .. "\n"
    end
    return self:writeEntry(-math.huge, {metadata = metadata})
end

---formats an entry to a human-readable string
--- usually it is of the format `index:[key: value, ...]`
--- if it has attributes outside of what an entry is supposed to have, they are added to the end: format `index:[key: value, ...](unknownkey: value, ...)`
--- if index is unknown it is replaced with "-"
--- if entry is nil, returns "-:nil"
---@param entry entry?
---@return string
function GenericDataFile:formatEntry(entry)
    if not entry then
        return "-:nil"
    end
    local strings = {}
    for _, keyname in ipairs(self:getNameList() or {}) do
        local value = entry[keyname]
        if value then
            strings[#strings + 1] = keyname .. ": " .. value
        end
    end
    local other = {}
    local nameIndex = self:getNameIndex()
    for key, value in pairs(entry) do
        if not (nameIndex and nameIndex[key]) then
            other[#other + 1] = key .. ": " .. value
        end
    end
    return (entry["_i"] or "-") ..
        ":[" .. table.concat(strings, ", ") .. "]" .. (#other > 0 and "(" .. table.concat(other, ",") .. ")" or "")
end

---find the first entry that matches pattern
---@param pattern table
---@param from integer
---@param to integer
---@param keys keysArg
---@return entry? entry
---@return integer? index
function GenericDataFile:find(pattern, from, to, keys)
    keys = keys and arrayfile_entry.splitArgString(keys)
    local i = from
    while i <= to do
        local current = self:getCached(i)
        local might, will = arrayfile_entry.entriesMightMatch(current, pattern)
        if might then
            if will then
                return self:readEntry(i, keys), i
            else
                current = self:readEntry(i, "!") -- here would go pattern's all keys, but it is already known that the cached does not contain all of them.
                might, will = arrayfile_entry.entriesMightMatch(current, pattern)
                if will then
                    return current, i
                end
            end
        end
        ---@cast current entry
        i = self:next(i, current) -- the change
    end
    return nil, nil
end

---find the first `count` entries that match the pattern
---@param pattern table
---@param from integer
---@param to integer
---@param keys keysArg
---@param max integer?
---@return table<integer,entry> entries
---@return integer count
function GenericDataFile:findMany(pattern, from, to, keys, max)
    keys = keys and arrayfile_entry.splitArgString(keys)
    local counter = 0
    local entries = {}
    ---@type integer?
    local i = from
    while i <= to do
        local entry
        entry, i = self:find(pattern, i --[[@as integer]], to, keys)
        if entry and i then
            entries[i] = entry
            counter = counter + 1
            if max and max <= counter then
                break
            end
            i = self:next(i, entry)
        else
            break
        end
    end
    return entries, counter
end

---makes a branch, which can be commited or rolled back.
---@return CachedDataFile
function GenericDataFile:branch()
    return require("CachedDataFile").make(self, math.huge, 10)
    -- -- todo
    -- return setmetatable(
    --     {
    --         parent = self,
    --         writecache = {}
    --     },
    --     BranchCachedDataFile
    -- )
end

return GenericDataFile
