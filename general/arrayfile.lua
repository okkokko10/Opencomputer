local Helper = require "Helper"
---@alias buffer file*

---an entry in an arrayfile.
---@class entry: table<string,any>
---@field _i integer -- index in the array
---@field _R integer? -- todo: important reference count. a cached entry is not cleared if this is positive
---@field [string] any

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
---@field file_offset integer -- see [positionstream.offset]
local arrayfile = {}

arrayfile.__index = arrayfile

---determines how much space at the beginning of the file will be allocated for metadata. (not counting two rows that describe nameList and formats)
---added to file_offset
---the whole of the metadata string can be accessed with self:readEntry(-math.huge)
arrayfile.metadataSize = 128

---splits a string by whitespace/punctuation
---if it's already split, do nothing and return it
---@param str string|string[]
---@return string[]
function arrayfile.splitArgString(str)
    if type(str) == "string" then
        return {Helper.splitString(str, "[%s%p]+", true)}
    else
        return str
    end
end

---creates a new arrayfile object
---@param filename string
---@param nameList? string[] |string -- if nil, reads the first 2 lines of the file and uses them as nameList and formats (if the second line is empty, the first is interpreted as alternating as if formats=nil)
---@param formats? string[] |string -- sequence or space/punctuation-separated string.pack format strings. if nil,  reads namelist as alternating [name, format ...]
function arrayfile.make(filename, nameList, formats)
    checkArg(1, filename, "string")
    local file_offset = arrayfile.metadataSize
    local read_stream
    if not nameList then
        local readf = io.open(filename, "rb")
        assert(readf, "cannot read file " .. filename)
        nameList = readf:read("L") or ""
        formats = readf:read("L") or ""
        file_offset = file_offset + #formats + #nameList
        local stripPattern = "^[%s%p]*(.-)[%s%p]*$"
        nameList = string.match(nameList, stripPattern)
        formats = string.match(formats, stripPattern)
        if formats == "" then -- alternating on first line.
            formats = nil
        end
        read_stream = arrayfile.positionstream.make(readf, file_offset)
    else
    end

    nameList = arrayfile.splitArgString(nameList)
    if not formats then
        -- `formats` can be of the form "[name In ...]"
        local f = {}
        local n = {}
        for i = 1, #nameList do
            if i % 2 == 0 then
                f[#f + 1] = nameList[i]
            else
                n[#n + 1] = nameList[i]
            end
        end
        nameList = n
        formats = f
    else
        formats = arrayfile.splitArgString(formats)
    end
    ---@type arrayfile
    local arrf =
        setmetatable(
        {filename = filename, formats = formats, nameList = nameList, wholeFormat = table.concat(formats, " ")},
        arrayfile
    )
    arrf.file_offset = file_offset
    arrf.read_stream = read_stream
    local nameIndex = {}
    for i = 1, #(nameList or "") do
        nameIndex[nameList[i]] = i
        nameIndex[i] = i -- makes it so valid number indices are recognized
    end
    nameIndex["_i"] = "_i"
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
            return rawget(
                entry,
                arrf.nameIndex[key] or
                    error(
                        'no such key: "' ..
                            key .. '" in arrayfile "' .. filename .. '". valid keys: ' .. table.concat(nameList, " ")
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
                            key .. '" in arrayfile "' .. filename .. '". valid keys: ' .. table.concat(nameList, " ")
                    ),
                value
            )
        end
    }
    return arrf
end

---sets entry metatable, and index
---note: does not actually set the entry.
---@param entry table
---@param index integer
---@return entry
function arrayfile:makeEntry(entry, index)
    entry._i = index
    return setmetatable(entry, self.entryMetatable)
end

---turns bytes into an entry
---@param data string
---@return entry entry
function arrayfile:decode(data, index)
    local entry = {string.unpack(self.wholeFormat, data)}
    entry[#entry] = nil
    return self:makeEntry(entry, index)
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
    self:setRead(io.open(self.filename, "rb"), self.file_offset)
    return self.read_stream
end
function arrayfile:openWrite()
    self:setWrite(io.open(self.filename, "ab"), self.file_offset)
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

function arrayfile:setRead(stream, offset)
    self:closeRead()
    self.read_stream = self.positionstream.make(stream, offset)
end

function arrayfile:setWrite(stream, offset)
    self:closeWrite()
    self.write_stream = self.positionstream.make(stream, offset)
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
---@field offset integer -- start at this position of the actualstream. use to place other data at the beginning.
---@field read_seek_max integer -- how far can read be used to seek. default 2000
arrayfile.positionstream = {}
arrayfile.positionstream.__index = arrayfile.positionstream

---create a positionstream from a stream.
---@param actualstream buffer
---@param offset? integer -- it's like the first `offset` bytes aren't even there
---@return positionstream
function arrayfile.positionstream.make(actualstream, offset)
    assert((offset or 0) >= 0)
    -- position starts as math.huge so that the first seek must set absolute position
    return setmetatable(
        {actualstream = actualstream, position = math.huge, flushed = true, offset = offset or 0, read_seek_max = 2000},
        arrayfile.positionstream
    )
end

function arrayfile.positionstream:setOffset(offset)
    assert(offset >= 0)
    self.offset = offset
end

---comment
---@param position integer
function arrayfile.positionstream:seek(position)
    if position == nil then
        return
    end
    if self.position == position then
        return
    else
        local distance = position - self.position
        ---@diagnostic disable-next-line: undefined-field
        if self.actualstream.mode.r and 0 < distance and distance < self.read_seek_max then -- todo: 1000 is arbitrary.
            self:read(nil, distance) -- often just reading the stream is faster than seeking. not possible for write
        else
            local newpos = self.actualstream:seek("set", position + self.offset) - self.offset
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
    local resultlength = #(out or "")
    self.position = self.position + resultlength
    if resultlength < length then
        return out .. string.rep("\0", length - resultlength)
    end
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
---@param keys nil|true|string|string[]
---@return entry entry
function arrayfile:readEntry(index, keys)
    local entry = self:readEntryDirect(index)
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
---like updateEntry, but not in place.
---@param targetEntry entry
---@param newValues entry
---@return entry
function arrayfile.updatedEntry(targetEntry,newValues)
    local new = setmetatable({},getmetatable(targetEntry))
    arrayfile.updateEntry(new,targetEntry)
    arrayfile.updateEntry(new,newValues)
    return new 
end


---updates targetEntry with values in newValues, but an existing value must be the same or it causes an error
---@param targetEntry entry
---@param newValues entry
function arrayfile.updateEntrySubsetCheck(targetEntry, newValues)
    for i, value in pairs(newValues) do -- this works whether or not entry has entryMetatable
        -- self.entryMetatable.__newindex(original, i, value)
        local old = targetEntry[i]
        if old then
            assert(value == old, "new value didn't match up with old value")
        else
            targetEntry[i] = value
        end
    end
end

---readEntryValues, but additionally returns its values in the order given in keys
---@param index integer
---@param keys string|string[]
---@return entry entry
---@return ... any -- values corresponding to keys
function arrayfile:readEntryFancy(index, keys)
    keys = arrayfile.splitArgString(keys)
    local entry = self:readEntry(index, keys) -- todo: cache
    return entry, arrayfile.unpackEntry(entry, keys)
end

---do multiple readEntryValues at once.
---proper way to query values.
--- {[3]="a b c",[5]="d c"} => {[3]={a=?,b=?,c=?},[5]={d=?,c=?}}
---@param indices_keys table<integer,true|string|string[]>
---@return table<integer,entry> indices_entries
function arrayfile:readEntries(indices_keys)
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
function arrayfile:writeEntries(indices_entries)
    for index, entry in Helper.sortedpairs(indices_entries) do
        self:writeEntry(index, entry)
    end
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function arrayfile:writeEntry(index, entry)
    if index == -math.huge then
        if entry.metadata then
            assert(#entry.metadata <= self.metadataSize, entry.metadata)
            self:getWrite():write(-self.metadataSize, entry.metadata)
        end
        return
    end
    local encoded = self:encode(entry)
    for i = 1, #encoded do
        self:getWrite():write(self:getPosition(index, encoded[i][1]), encoded[i][2])
    end
end

---@param index integer
---@return entry entry
function arrayfile:readEntryDirect(index)
    if index == -math.huge then
        return self:getRead():read(-self.metadataSize, self.metadataSize)
    end
    local data = self:getRead():read(self:getPosition(index), self.size)
    return self:decode(data, index)
end

---entry must be a subset of otherEntry.
---return an entry that contains entry, but has less or equal holes
---for use in write, so that one does not need to seek.
---@param entry entry
---@param otherEntry entry?
---@return entry
function arrayfile.entryHolesFilled(entry, otherEntry)
    if not otherEntry then
        return entry
    else
        return otherEntry -- todo: smarter.
    end
end

function arrayfile:readMetadata()
    return self:readEntry(-math.huge).metadata
end
---comment
---@param string string
---@return nil
function arrayfile:writeMetadata(string)
    local metadata = string.sub(string, 1, self.metadataSize)
    local padding = self.metadataSize - #metadata
    if padding > 0 then
        metadata = metadata .. string.rep("\0", padding - 1) .. "\n"
    end
    return self:writeEntry(-math.huge, {metadata = metadata})
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
