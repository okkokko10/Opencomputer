local Helper = require "Helper"
local arrayfile_entry = require "arrayfile_entry"
local arrayfile = require "arrayfile"

---@class AppendStringListFile
---@field filename string
---@field read_stream positionstream
---@field write_stream positionstream
---@field file_offset integer -- see [positionstream.offset]
local AppendStringListFile = {}

AppendStringListFile.__index = AppendStringListFile

---determines how much space at the beginning of the file will be allocated for metadata. (not counting two rows that describe nameList and formats)
---added to file_offset
---the whole of the metadata string can be accessed with self:readEntry(-math.huge)
AppendStringListFile.metadataSize = 128

---creates a new AppendStringListFile object
---@param filename string
function AppendStringListFile.make(filename)
    checkArg(1, filename, "string")
    local file_offset = AppendStringListFile.metadataSize

    ---@type AppendStringListFile
    local aslf = setmetatable({filename = filename}, AppendStringListFile)
    aslf.file_offset = file_offset

    return aslf
end

AppendStringListFile.nameList = {"text"}
AppendStringListFile.nameIndex = {text = "text", _i = "_i"}

---sets entry metatable, and index
---note: does not actually set the entry.
---@param entry table
---@param index integer
---@return entry
function AppendStringListFile:makeEntry(entry, index)
    entry._i = index
    return entry
    --setmetatable(entry, self.entryMetatable)
end

---turns text into an entry
---@param text string
---@return entry entry
function AppendStringListFile:decode(text, index)
    local entry = {text = text}
    return self:makeEntry(entry, index)
end

---if some indices are nil, then they are left as they are
---@param entry entry
---@return [integer,string][] offset-bytestring
function AppendStringListFile:encode(entry)
    local text = entry.text

    return {{0, string.pack("I2", #text) .. text}}
end

function AppendStringListFile:openRead()
    self:setRead(io.open(self.filename, "rb"), self.file_offset)
    return self.read_stream
end
function AppendStringListFile:openWrite()
    -- arrayfile.openWrite
    self:setWrite(io.open(self.filename, "ab"), self.file_offset)
    return self.write_stream
end
function AppendStringListFile:closeRead()
    if self.read_stream then
        self.read_stream:close()
        self.read_stream = nil
    end
end
function AppendStringListFile:closeWrite()
    if self.write_stream then
        self.write_stream:close()
        self.write_stream = nil
    end
end

function AppendStringListFile:close()
    self:closeRead()
    self:closeWrite()
end

function AppendStringListFile:setRead(stream, offset)
    self:closeRead()
    self.read_stream = arrayfile.positionstream.make(stream, offset)
end

function AppendStringListFile:setWrite(stream, offset)
    self:closeWrite()
    self.write_stream = arrayfile.positionstream.make(stream, offset)
end

function AppendStringListFile:getRead()
    return self.read_stream or self:openRead() -- todo: this automatically opens a read. is this okay?
end
function AppendStringListFile:getWrite()
    return self.write_stream or self:openWrite()
end

function AppendStringListFile:getPosition(index, offset)
    return index + (offset or 0)
end

---readEntry, except it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys nil|false|string|string[]
---@return entry entry
function AppendStringListFile:readEntry(index, keys)
    local entry = self:readEntryDirect(index)
    return entry
end

---do multiple readEntryValues at once.
---proper way to query values.
--- {[3]="a b c",[5]="d c"} => {[3]={a=?,b=?,c=?},[5]={d=?,c=?}}
---@param indices_keys table<integer,true|string|string[]>
---@return table<integer,entry> indices_entries
function AppendStringListFile:readEntries(indices_keys)
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
function AppendStringListFile:writeEntries(indices_entries)
    for index, entry in Helper.sortedpairs(indices_entries) do
        self:writeEntry(index, entry)
    end
end

---writes entry to index. if some values are blank, they are left as is
---@param position integer
---@param entry table
function AppendStringListFile:writeEntry(position, entry)
    if position == -math.huge then
        if entry.metadata then
            assert(#entry.metadata <= self.metadataSize, entry.metadata)
            self:getWrite():write(-self.metadataSize, entry.metadata)
        end
        return
    end
    local encoded = self:encode(entry)
    for i = 1, #encoded do
        self:getWrite():write(self:getPosition(position, encoded[i][1]), encoded[i][2])
    end
end

---@param position integer
---@return entry entry
function AppendStringListFile:readEntryDirect(position)
    if position == -math.huge then
        return self:getRead():read(-self.metadataSize, self.metadataSize)
    end
    local reader = self:getRead()
    local length = string.unpack("I2", reader:read(position, 2))
    local text = reader:read(nil, length)
    return self:decode(text, position)
end

---gets the metadata string, of length `self.metadataSize`
---@return string
function AppendStringListFile:readMetadata() -- unchanged
    return self:readEntry(-math.huge).metadata
end
---comment
---@param string string
---@return nil
function AppendStringListFile:writeMetadata(string) -- unchanged
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
function AppendStringListFile:getCached(index)
    return nil
end

---formats an entry to a human-readable string
--- usually it is of the format `index:[key: value, ...]`
--- if it has attributes outside of what an entry is supposed to have, they are added to the end: format `index:[key: value, ...](unknownkey: value, ...)`
--- if index is unknown it is replaced with "-"
--- if entry is nil, returns "-:nil"
---@param entry entry?
---@return string
function AppendStringListFile:formatEntry(entry) -- unchanged
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

---returns the position of the entry after this one
---@param entry entry
---@return integer
function AppendStringListFile:next(entry)
    return entry._i + #entry.text + 2
end

---find the first entry that matches pattern
---@param pattern entry
---@param from integer
---@param to integer
---@param keys string[] | string | nil | false
---@return entry?
---@return integer?
function AppendStringListFile:find(pattern, from, to, keys) -- changed slightly. should be pushed to be the generic definition
    keys = keys and arrayfile_entry.splitArgString(keys)
    local i = from
    while i <= to do -- changed
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
        i = self:next(current) -- the change
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
function AppendStringListFile:findMany(pattern, from, to, keys, max) -- changed slightly
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
            i = self:next(entry) -- the change
        else
            break
        end
    end
    return entries
end

return AppendStringListFile
