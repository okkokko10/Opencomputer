local CachedDataFile = require "CachedDataFile"
---@class SparseDataFile: CachedDataFile
local SparseDataFile = setmetatable({}, CachedDataFile)
SparseDataFile.__index = SparseDataFile

--- only exists when loaded / is saved serialized

--- todo: only beginning

---@param filename string
function SparseDataFile.make(filename)
    local arrf = {}
    ---@cast arrf SparseDataFile
    -- arrf.base = base
    arrf.writecache = {}
    arrf.write_current_size = 0
    arrf.write_max_size = math.huge
    arrf.readcache = {}
    arrf.read_current_size = 0
    arrf.read_max_size = math.huge
    return setmetatable(arrf, SparseDataFile)
end

function SparseDataFile:clearReadcache()
    self:flushWrites()
end

---write changes to base
---@return GenericDataFile
function SparseDataFile:commit()
    self.base:writeEntries(self.writecache)
    self.writecache = {}
    self.write_current_size = 0
    return self.base
end

---undo changes since last commit
---@return GenericDataFile
function SparseDataFile:rollback()
    self.writecache = {}
    self.write_current_size = 0
    self.readcache = {}
    self.read_current_size = 0
    return self.base
end

return SparseDataFile
