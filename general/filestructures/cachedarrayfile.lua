local arrayfile = require("arrayfile")
local CachedDataFile = require("CachedDataFile")

---@class cachedarrayfile: CachedDataFile
local cachedarrayfile = {}

---creates a new cachedarrayfile object
---@param filename string
---@param nameList? string[] |string
---@param formats? string[] |string -- sequence or space/punctuation-separated string.pack format strings
---@param write_max_size? integer = 1000
---@param read_max_size? integer = 1000
function cachedarrayfile.make(filename, nameList, formats, write_max_size, read_max_size)
    return CachedDataFile.make(arrayfile.make(filename, nameList, formats), write_max_size, read_max_size)
end

return cachedarrayfile
