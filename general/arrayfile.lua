local Helper = require "Helper"
local arrayfile_entry = require("arrayfile_entry")
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

    arrf.entryMetatable = arrayfile_entry.makeEntryMetatable(arrf)
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
---@param keys nil|false|string|string[]
---@return entry entry
function arrayfile:readEntry(index, keys)
    local entry = self:readEntryDirect(index)
    return entry
end

---readEntryValues, but additionally returns its values in the order given in keys
---@param index integer
---@param keys string|string[]
---@return entry entry
---@return ... any -- values corresponding to keys
function arrayfile:readEntryFancy(index, keys)
    keys = arrayfile.splitArgString(keys)
    local entry = self:readEntry(index, keys) -- todo: cache
    return entry, arrayfile_entry.unpackEntry(entry, keys)
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

---gets the metadata string, of length `self.metadataSize`
---@return string
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

---get a cached entry, if caching exists. otherwise get nothing
---@param index integer
---@return entry?
function arrayfile:getCached(index)
    return nil
end

---formats an entry to a human-readable string
--- usually it is of the format `index:[key: value, ...]`
--- if it has attributes outside of what an entry is supposed to have, they are added to the end: format `index:[key: value, ...](unknownkey: value, ...)`
--- if index is unknown it is replaced with "-"
--- if entry is nil, returns "-:nil"
---@param entry entry?
---@return string
function arrayfile:formatEntry(entry)
    if not entry then
        return "-:nil"
    end
    local strings = {}
    for _, keyname in ipairs(self.nameList) do
        local value = entry[keyname]
        if value then
            strings[#strings + 1] = keyname .. ": " .. value
        end
    end
    local other = {}
    for key, value in pairs(entry) do
        if not self.nameIndex[key] then
            other[#other + 1] = key .. ": " .. value
        end
    end
    return (entry["_i"] or "-") ..
        ":[" .. table.concat(strings, ", ") .. "]" .. (#other > 0 and "(" .. table.concat(other, ",") .. ")" or "")
end

---find the first entry that matches pattern
---@param pattern entry
---@param from integer
---@param to integer
---@param keys string[] | string | nil | false
---@return entry?
---@return integer?
function arrayfile:find(pattern, from, to, keys)
    keys = keys and arrayfile.splitArgString(keys)
    for i = from, to do
        local cached = self:getCached(i)
        local might, will = arrayfile_entry.entriesMightMatch(cached, pattern)
        if might then
            if will then
                return self:readEntry(i, keys), i
            else
                local read = self:readEntry(i, "!") -- here would go pattern's all keys, but it is already known that the cached does not contain all of them.
                might, will = arrayfile_entry.entriesMightMatch(read, pattern)
                if will then
                    return read, i
                end
            end
        end
    end
    return nil, nil
end

---find the first `count` entries that match the pattern
---@param pattern entry
---@param from integer
---@param to integer
---@param keys string[] | string | nil | false
---@param max integer?
---@return entry?
---@return integer?
function arrayfile:findMany(pattern, from, to, keys, max)
    keys = keys and arrayfile.splitArgString(keys)
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
            i = i + 1
        else
            break
        end
    end
    return entries
end

return arrayfile
