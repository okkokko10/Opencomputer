local Helper = require "Helper"
---@alias buffer table

---@alias entry table

--[[
```
public methods:
    arrayfile.make
    arrayfile:readEntriesValues
    arrayfile:writeEntries


call tree:
    readEntriesValues
        readEntryValues
            readEntry
                (read_stream)
                _read
                    _seek
                decode
    writeEntries
        writeEntry
            encode
            (write_stream)
            _write
                _seek
                

```
]]
---@class arrayfile
---@field filename string
---@field nameIndex table<string,integer>
---@field nameList string[]
---@field wholeFormat string
---@field formats string[]
---@field offsets integer[]
---@field size integer
---@field sizes integer[] -- currently unused
---@field entryMetatable table
---@field read_stream positionstream
---@field write_stream positionstream
local arrayfile = {}

arrayfile.__index = arrayfile

---splits a string by whitespace/punctuation
---if it's already split, do nothing and return it
---@param str string|string[]
---@return string[]
function arrayfile.splitArgString(str)
    if type(str) == "string" then
        return {Helper.splitString(str, "[%s%p]*")}
    else
        return str
    end
end

---creates a new arrayfile object
---@param filename string
---@param formats string[] |string -- sequence or space/punctuation-separated string.pack format strings
---@param nameList string[] |string
function arrayfile.make(filename, formats, nameList)
    formats = arrayfile.splitArgString(formats)
    nameList = arrayfile.splitArgString(nameList)
    ---@type arrayfile
    local arrf =
        setmetatable(
        {filename = filename, formats = formats, nameList = nameList, wholeFormat = table.concat(formats, " ")},
        arrayfile
    )
    local nameIndex = {}
    for i = 1, #(nameList or "") do
        nameIndex[nameList[i]] = i
    end
    arrf.nameIndex = nameIndex
    local offsets = {}
    local size = 0
    for i = 1, #formats do
        offsets[i] = size
        size = size + string.packsize(formats[i])
    end
    arrf.size = size
    arrf.offsets = offsets

    arrf.entryMetatable = {
        __index = function(entry, key)
            return entry[
                arrf.nameIndex[key] or
                    error(
                        'no such key: "' ..
                            key .. '" in arrayfile "' .. filename .. '". valid keys: ' .. table.concat(nameList, " ")
                    )
            ]
        end,
        --- todo: this might be better to not enable? it should be immutable
        __newindex = function(entry, key, value)
            entry[
                    arrf.nameIndex[key] or
                        error(
                            'no such key: "' ..
                                key ..
                                    '" in arrayfile "' .. filename .. '". valid keys: ' .. table.concat(nameList, " ")
                        )
                ] = value
        end
    }
    return arrf
end

---turns bytes into an entry
---@param data string
---@return entry entry
function arrayfile:decode(data)
    return setmetatable({string.unpack(self.wholeFormat, data)}, self.entryMetatable)
end

---if some indices are nil, then they are left as they are
---@param entry entry
---@return [integer,string][] offset-bytestring
function arrayfile:encode(entry)
    ---@type [integer,string]
    local current = {0, ""}
    local pairs = {current}
    for i = 1, #self.nameList do
        local value = entry[self.nameList[i]]
        if value == nil then -- now value can even be a boolean
            local nextOffset = self.offsets[i + 1]
            if current[2] == "" then
                current[1] = nextOffset -- in theory removes current and adds new.
            else
                current = {nextOffset, ""}
                pairs[#pairs + 1] = current
            end
        else
            current[2] = current[2] .. string.pack(self.formats[i], value)
        end
    end
    if current[2] == "" then
        pairs[#pairs] = nil
    end
    return pairs
end

function arrayfile:openRead()
    self:setRead(io.open(self.filename, "rb"))
    return self.read_stream
end
function arrayfile:openWrite()
    self:setWrite(io.open(self.filename, "ab"))
    return self.write_stream
end
function arrayfile:closeRead()
    if self.read_stream then
        self.read_stream:close()
        self.read_stream = nil
    end
end
function arrayfile:closeWrite()
    if self.write_stream then
        self.write_stream:close()
        self.write_stream = nil
    end
end

function arrayfile:close()
    self:closeRead()
    self:closeWrite()
end

function arrayfile:setRead(stream)
    self:closeRead()
    self.read_stream = self.positionstream.make(stream)
end

function arrayfile:setWrite(stream)
    self:closeWrite()
    self.write_stream = self.positionstream.make(stream)
end

function arrayfile:getRead()
    return self.read_stream or self:openRead() -- todo: this automatically opens a read. is this okay?
end
function arrayfile:getWrite()
    return self.write_stream or self:openWrite()
end

function arrayfile:getPosition(index, offset)
    return index * self.size + (offset or 0)
end

---@class positionstream
---@field actualstream buffer
---@field position integer
---@field flushed boolean
arrayfile.positionstream = {}
arrayfile.positionstream.__index = arrayfile.positionstream

---@param actualstream buffer
---@return positionstream
function arrayfile.positionstream.make(actualstream)
    -- position starts as maxinteger so that the first seek must set absolute position
    return setmetatable(
        {actualstream = actualstream, position = math.maxinteger, flushed = true},
        arrayfile.positionstream
    )
end

---comment
---@param position integer
function arrayfile.positionstream:seek(position)
    if self.position == position then
        return
    else
        local distance = position - self.position
        if self.actualstream.mode.r and 0 < distance and distance < 1000 then -- todo: 1000 is arbitrary.
            self:read(distance) -- often just reading the stream is faster than seeking. not possible for write
        else
            local newpos = self.actualstream:seek("set", position)
            self.position = newpos
        end
    end
end

function arrayfile.positionstream:write(position, str)
    self:seek(position)
    self.actualstream:write(str)
    self.position = self.position + #str
    self.flushed = false
end

function arrayfile.positionstream:read(position, length)
    self:seek(position)
    local out = self.actualstream:read(length)
    self.position = self.position + #(out or "")
    return out
end

function arrayfile.positionstream:flush()
    self.flushed = true
    return self.actualstream:flush()
end
function arrayfile.positionstream:close()
    return self.actualstream:close()
end

---readEntry, except it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys string|string[]
---@return entry entry
function arrayfile:readEntryValues(index, keys)
    local entry = self:readEntry(index) -- todo: cache
    keys = arrayfile.splitArgString(keys)
    return entry
end

---unpacks the entry with the given keys
---@param entry entry
---@param keys string|string[]
---@return any ...
function arrayfile.unpackEntry(entry, keys)
    keys = arrayfile.splitArgString(keys)
    local unpacked = {}
    for i = 1, #keys do
        unpacked[i] = entry[keys[i]]
    end
    return table.unpack(unpacked, 1, #keys)
end

---updates targetEntry with values in newValues
---@param targetEntry entry
---@param newValues entry
function arrayfile.updateEntry(targetEntry, newValues)
    for i, value in pairs(newValues) do -- this works whether or not entry has entryMetatable
        -- self.entryMetatable.__newindex(original, i, value)
        targetEntry[i] = value
    end
end

---readEntryValues, but additionally returns its values in the order given in keys
---@param index integer
---@param keys string|string[]
---@return entry entry
---@return ... any -- values corresponding to keys
function arrayfile:readEntryValuesFancy(index, keys)
    keys = arrayfile.splitArgString(keys)
    local entry = self:readEntryValues(index, keys) -- todo: cache
    return entry, arrayfile.unpackEntry(entry, keys)
end

---do multiple readEntryValues at once.
---proper way to query values.
--- {[3]="a b c",[5]="d c"} => {[3]={a=?,b=?,c=?},[5]={d=?,c=?}}
---@param indices_keys table<integer,string|string[]>
---@return table<integer,entry> indices_entries
function arrayfile:readEntriesValues(indices_keys)
    local indices_entries = {}
    for index, keys in Helper.sortedpairs(indices_keys) do
        indices_entries[index] = self:readEntryValues(index, keys)
    end
    return indices_entries
end

---writes entries. in a sense updates this with indices_entries.
---nil keeps old value
---@param indices_entries table<integer,entry>
function arrayfile:writeEntries(indices_entries)
    for index, entry in Helper.sortedpairs(indices_entries) do
        self:writeEntry(index, entry)
    end
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry entry
function arrayfile:writeEntry(index, entry)
    local encoded = self:encode(entry)
    for i = 1, #encoded do
        self:getWrite():write(self:getPosition(index, encoded[i][1]), encoded[i][2])
    end
end

---todo: buffer
---@param index integer
---@return entry entry
function arrayfile:readEntry(index)
    local data = self:getRead():read(self:getPosition(index), self.size)
    return self:decode(data)
end

-- ---encodes a complete entry
-- ---@param entry table
-- function arrayfile:encode(entry)
--     local ordered = {}
--     for i = 1, #self.nameList do
--         ordered[i] = entry[self.nameList[i]]
--     end
--     return string.pack(self.wholeFormat, table.unpack(ordered))
-- end

-- ---todo: implement smarter
-- ---@param index integer
-- ---@param ... integer
-- ---@return entry? entry
-- ---@return ... entry
-- function arrayfile:readEntries(index, ...)
--     if not index then
--         return nil
--     end
--     return self:readEntry(index), self:readEntries(...)
-- end

return arrayfile
