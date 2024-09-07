local Helper = require "Helper"
local arrayfile_entry = require("arrayfile_entry")
local positionstream = require("positionstream")
local GenericDataFile = require("GenericDataFile")
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
---@class arrayfile: GenericDataFile
---@field filename string
---@field nameIndex table<string,integer|string> -- from external to internal entry key names
---@field nameList string[] -- list of entry key names
---@field wholeFormat string
---@field formats string[]
---@field offsets integer[]
---@field size integer
---@field sizes integer[] -- currently unused
---@field entryMetatable table
---@field read_stream positionstream
---@field write_stream positionstream
---@field file_offset integer -- see [positionstream.offset]
local arrayfile = setmetatable({}, GenericDataFile)

arrayfile.__index = arrayfile

---determines how much space at the beginning of the file will be allocated for metadata. (not counting two rows that describe nameList and formats)
---added to file_offset
---the whole of the metadata string can be accessed with self:readEntry(-math.huge)
arrayfile.metadataSize = 128

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
        read_stream = positionstream.make(readf, file_offset)
    else
    end

    nameList = arrayfile_entry.splitArgString(nameList) --[[@as string[] ]]
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
        formats = arrayfile_entry.splitArgString(formats) --[[@as string[] ]]
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
---sequence of (offset,bytes), where if an entry starts at position x, bytes should be written starting from x+offset
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

arrayfile.close = GenericDataFile.close

function arrayfile:setRead(stream, offset)
    self:closeRead()
    self.read_stream = positionstream.make(stream, offset)
end

function arrayfile:setWrite(stream, offset)
    self:closeWrite()
    self.write_stream = positionstream.make(stream, offset)
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

arrayfile.readEntryFancy = GenericDataFile.readEntryFancy

arrayfile.readEntries = GenericDataFile.readEntries

arrayfile.writeEntries = GenericDataFile.writeEntries

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function arrayfile:writeEntry(index, entry)
    if index == -math.huge then
        if entry.metadata then
            assert(#entry.metadata <= self.metadataSize, entry.metadata)
            self:getWrite():write(-self.metadataSize, entry.metadata)
        end
    else
        local encoded = self:encode(entry)
        for i = 1, #encoded do
            self:getWrite():write(self:getPosition(index, encoded[i][1]), encoded[i][2])
        end
    end
end

---@param index integer
---@param keys keysArg
---@return entry entry
function arrayfile:readEntry(index, keys)
    if index == -math.huge then
        return {metadata = self:getRead():read(-self.metadataSize, self.metadataSize), _i = -math.huge}
    end
    local data = self:getRead():read(self:getPosition(index), self.size)
    return self:decode(data, index)
end

arrayfile.getCached = GenericDataFile.getCached

arrayfile.formatEntry = GenericDataFile.formatEntry

---returns the position of the entry after this one
---@param entry entry
---@return integer
function arrayfile:next(entry)
    return entry._i + 1
end

arrayfile.find = GenericDataFile.find
arrayfile.findMany = GenericDataFile.findMany

return arrayfile
