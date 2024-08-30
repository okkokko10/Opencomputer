local Helper = require "Helper"
---@alias buffer table

---@alias entry table

---@class arrayfile
---@field read_stream buffer
---@field write_stream buffer
---@field read_index integer
---@field write_index integer
---@field filename string
---@field nameIndex table<string,integer>
---@field nameList string[]
---@field offsets integer[]
---@field size integer
---@field sizes integer[]
---@field wholeFormat string
---@field formats string[]
---@field entryMetatable table
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

---opens a file
---@param filename string
---@param formats string[] |string -- sequence or space/punctuation-separated string.pack format strings
---@param nameList string[] |string
function arrayfile.make(filename, formats, nameList)
    formats = arrayfile.splitArgString(formats)
    nameList = arrayfile.splitArgString(nameList)
    local arrf = {filename = filename, formats = formats, nameList = nameList, wholeFormat = table.concat(formats, " ")}
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
        end
    }

    return setmetatable(arrf, arrayfile)
end

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

function arrayfile:setRead(stream)
    self.read_stream = stream
    self.read_index = 0
end
function arrayfile:setWrite(stream)
    self.write_stream = stream
    self.write_index = 0
end

function arrayfile:_read_seek(index, offset)
    local position = index * self.size + (offset or 0)
    if self.read_index == position then
        return
    else
        local distance = position - self.read_index
        if 0 < distance and distance < 1000 then -- todo: 1000 is arbitrary.
            self:_read(distance) -- often just reading the stream is faster than seeking. not possible for write
        else
            local newpos = self.read_stream:seek("set", position)
            self.read_index = newpos
        end
    end
end
function arrayfile:_write_seek(index, offset)
    local position = index * self.size + (offset or 0)
    if self.write_index == position then
        return
    else
        local newpos = self.write_stream:seek("set", position)
        self.write_index = newpos
    end
end

function arrayfile:_write(str)
    self.write_stream:write(str)
    self.write_index = self.write_index + #str
end

function arrayfile:_read(length)
    local out = self.read_stream:read(length)
    self.read_index = self.read_index + #(out or "")
    return out
end

---readEntry, except it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---returns the entry, then its values in the order given in keys
---@param index integer
---@param keys string|string[]
---@return entry entry
---@return ... any -- values corresponding to keys
function arrayfile:readEntryValues(index, keys)
    local entry = self:readEntry(index) -- todo: cache
    keys = arrayfile.splitArgString(keys)
    local unpacked = {}
    for i = 1, #keys do
        unpacked[i] = entry[keys[i]]
    end
    return entry, table.unpack(unpacked, 1, #keys)
end

---do multiple readEntryValues at once.
---proper way to query values.
--- {[3]="a b c",[5]="d c"} => {[3]={a=?,b=?,c=?},[5]={d=?,c=?}}
---@param indices_keys table<integer,string|string[]>
---@return table<integer,entry> entries
function arrayfile:readEntriesValues(indices_keys)
    local entries = {}
    table.sort(indices_keys) -- todo: does this work?
    for index, keys in pairs(indices_keys) do
        entries[index] = self:readEntryValues(index, keys)
    end
    return entries
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry entry
function arrayfile:writeEntry(index, entry)
    local encoded = self:encode(entry)
    for i = 1, #encoded do
        self:_write_seek(index, encoded[i][1])
        self:_write(encoded[i][2])
    end
end

---todo: buffer
---@param index integer
---@return entry entry
function arrayfile:readEntry(index)
    self:_read_seek(index)
    local data = self:_read(self.size)
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
