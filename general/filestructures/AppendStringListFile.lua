local Helper = require "Helper"
local arrayfile_entry = require "arrayfile_entry"
local arrayfile = require "arrayfile"
local positionstream = require("positionstream")
local GenericDataFile = require("GenericDataFile")
local DirectDataFile = require("DirectDataFile")

---@class AppendStringListFile: GenericDataFile, DirectDataFile
---@field filename string
---@field read_stream positionstream
---@field write_stream positionstream
---@field file_offset integer -- see [positionstream.offset]
local AppendStringListFile = setmetatable({}, GenericDataFile)

AppendStringListFile.__index = AppendStringListFile

---determines how much space at the beginning of the file will be allocated for metadata. (not counting two rows that describe nameList and formats)
---added to file_offset
---the whole of the metadata string can be accessed with self:readEntry(-math.huge)
AppendStringListFile.metadataSize = 128
AppendStringListFile.nameList = {"text"}
AppendStringListFile.nameIndex = {text = "text", _i = "_i"}

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

AppendStringListFile.openRead = DirectDataFile.openRead
AppendStringListFile.openWrite = DirectDataFile.openWrite
AppendStringListFile.closeRead = DirectDataFile.closeRead
AppendStringListFile.closeWrite = DirectDataFile.closeWrite
AppendStringListFile.setRead = DirectDataFile.setRead
AppendStringListFile.setWrite = DirectDataFile.setWrite
AppendStringListFile.getRead = DirectDataFile.getRead
AppendStringListFile.getWrite = DirectDataFile.getWrite

function AppendStringListFile:getPosition(index, offset)
    return index + (offset or 0)
end

---readEntry, except it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param position integer
---@param keys keysArg
---@return entry entry
function AppendStringListFile:readEntry(position, keys)
    if position == -math.huge then
        return {metadata = self:getRead():read(-self.metadataSize, self.metadataSize), _i = -math.huge}
    end
    local reader = self:getRead()
    local length = string.unpack("I2", reader:read(position, 2))
    local text = reader:read(nil, length)
    return self:decode(text, position)
end

AppendStringListFile.writeEntry = arrayfile.writeEntry

---returns the position of the entry after this one
---@param entry entry
---@return integer
function AppendStringListFile:next(entry)
    return entry._i + #entry.text + 2
end

return AppendStringListFile
