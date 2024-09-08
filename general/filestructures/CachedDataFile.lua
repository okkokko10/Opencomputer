local arrayfile = require("arrayfile")
local arrayfile_entry = require("arrayfile_entry")
local Helper = require("Helper")
local GenericDataFile = require("GenericDataFile")

---@class CachedDataFile: GenericDataFile
---@field base GenericDataFile
---@field writecache table<integer,entry>
---@field readcache table<integer,entry> -- if an entry exists, it is guaranteed to be up to date with writecache, and not have any more holes than writecache
---@field write_current_size integer
---@field read_current_size integer
---@field write_max_size integer
---@field read_max_size integer
---@field assume_behaviour { disabled: boolean?, check: boolean?, checkfile: boolean?, update: boolean? }? -- assume options
---@field private flush_suppressors table -- if nonempty, flush is suppressed
local CachedDataFile = setmetatable({}, GenericDataFile)

CachedDataFile.__index = CachedDataFile

---creates a new CachedDataFile object
---@param base GenericDataFile
---@param write_max_size? integer = 1000
---@param read_max_size? integer = 1000
function CachedDataFile.make(base, write_max_size, read_max_size)
    local arrf = {}
    ---@cast arrf CachedDataFile
    arrf.base = base
    arrf.writecache = {}
    arrf.write_current_size = 0
    arrf.write_max_size = write_max_size or 1000
    arrf.readcache = {}
    arrf.read_current_size = 0
    arrf.read_max_size = read_max_size or 1000
    arrf.flush_suppressors = setmetatable({}, {__mode = "k"})
    return setmetatable(arrf, CachedDataFile)
end

--#region cacheGetters

function CachedDataFile:getReadCache(index)
    return self.readcache[index]
end

function CachedDataFile:setReadCache(index, value)
    if self.readcache[index] == nil then
        self.write_current_size = self.write_current_size + 1
    end
    if value == nil then
        self.write_current_size = self.write_current_size - 1
    end
    self.readcache[index] = value
    return value
end

function CachedDataFile:updateReadCacheIfExists(index, value)
    local old = self:getReadCache(index)
    if old then
        self:setReadCache(index, arrayfile_entry.updatedEntry(old, value))
    end
end
function CachedDataFile:updateReadCache(index, value)
    self:setReadCache(index, arrayfile_entry.updatedEntry(self:getReadCache(index), value))
end
function CachedDataFile:setReadCacheUnlessExists(index, value)
    local old = self:getReadCache(index)
    if not old then
        self:setReadCache(index, value)
    end
end

function CachedDataFile:getWriteCache(index)
    return self.writecache[index]
end

function CachedDataFile:setWriteCache(index, value)
    if self.writecache[index] == nil then
        self.write_current_size = self.write_current_size + 1
    end
    if value == nil then
        self.write_current_size = self.write_current_size - 1
    end
    self.writecache[index] = value
end

function CachedDataFile:updateWriteCache(index, value)
    self:setWriteCache(index, arrayfile_entry.updatedEntry(self:getWriteCache(index), value))
end

---sets readcache with value plus writecache
---returns the set value
---@param index integer
---@param value entry
---@return entry
function CachedDataFile:setReadCacheWritten(index, value)
    return self:setReadCache(index, arrayfile_entry.updatedEntry(value, self:getWriteCache(index)))
end

--#endregion cacheGetters

--#region define abstract

---get a cached entry
---@param index integer
---@return entry?
function CachedDataFile:getCached(index)
    return self:getReadCache(index) or self:getWriteCache(index)
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function CachedDataFile:writeEntry(index, entry)
    self:updateWriteCache(index, entry)
    self:updateReadCacheIfExists(index, entry)
    self:checkCacheSize()
end

---only retrieves the stated keys if they are cached.
---if keys is false or nil, get all values
---if keys is "!", ignore cached.
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys keysArg
---@return entry entry
function CachedDataFile:readEntry(index, keys)
    if keys ~= "!" then
        local cached = self:getCached(index)
        if cached then
            if not keys then
                keys = self.base:getNameList()
            else
                keys = arrayfile_entry.splitArgString(keys)
            end
            if arrayfile_entry.entryHasKeys(cached, keys --[[@as string[] ]]) then
                return cached
            end
        end
    end

    local entry = self.base:readEntry(index, keys)
    self:checkCacheSize()
    return self:setReadCacheWritten(index, entry)
end

---returns the position of the entry after this one
---@param index integer
---@param entry entry?
---@return integer
function CachedDataFile:next(index, entry)
    return self.base:next(index, entry)
end

function CachedDataFile:closeRead()
    self.base:closeRead()
end
function CachedDataFile:closeWrite()
    self.base:closeWrite()
end

---@return table<string,integer|string> -- from external to internal entry key names
function CachedDataFile:getNameIndex()
    return self.base:getNameIndex()
end

---@return string[] -- list of entry key names
function CachedDataFile:getNameList()
    return self.base:getNameList()
end
---@return integer
function CachedDataFile:getMetadataSize()
    return self.base:getMetadataSize()
end

--#endregion define abstract

--#region flush

---returns an object that suppresses this from flushing until it gets `finish` called (or it is garbage collected)
---@return { finish:  fun() } suppressor
function CachedDataFile:suppressFlush()
    local suppressor
    suppressor = {
        finish = function()
            self.flush_suppressors[suppressor] = nil
        end
    }
    self.flush_suppressors[suppressor] = true
    return suppressor
end

function CachedDataFile:isFlushSuppressed()
    return next(self.flush_suppressors) ~= nil
end

---todo: this is kind of just commit
---flushes writes to the file. if saveToReadcache is true, the writecache is transferred to readcache instead of disappearing.
---@param saveToReadcache boolean?
function CachedDataFile:flushWrites(saveToReadcache)
    if self:isFlushSuppressed() then
        return nil, "suppressed"
    end
    -- essentially arrayfile:writeEntries
    for index, entry in Helper.sortedpairs(self.writecache) do
        if saveToReadcache then
            self:setReadCacheUnlessExists(index, entry)
        end
        -- self.base:writeEntry(index, arrayfile_entry.entryHolesFilled(entry, self:getReadCache(index))) -- since a readcache element is up to date with writecache when it exists, this might avoid unnecessary seeking
        self.base:writeEntry(index, entry) -- or getCached
        self:setWriteCache(index, nil) -- probably slower than necessary
    end
    -- self.writecache = {}
    -- self.write_current_size = 0
    self:closeWrite() -- todo: should this be optional?
    return true
end

---if caches are too large, flush/clear them.
function CachedDataFile:checkCacheSize()
    if self.write_current_size > self.write_max_size then
        self:flushWrites()
    end
    if self.read_current_size > self.read_max_size then
        local size = self.read_current_size
        local targetsize = self.read_max_size // 2 -- does not clear the cache entirely
        for index, _ in pairs(self.readcache) do -- the randomness of pairs is okay
            self.readcache[index] = nil
            size = size - 1
            if size < targetsize then
                break
            end
        end
        self.read_current_size = size
    end
end

function CachedDataFile:clearReadcache()
    self.readcache = {}
    self.read_current_size = 0
end

--#endregion flush

---warning: causes undefined behaviour if the input data is wrong on `update` setting.
---updates the entry in the readcache. this does not write to the array directly.
---works as an assertion if the data happens to already be cached: check if this matches it.
---tip: partially read entries' unread values are nil, so using them here works
---@param index integer
---@param entry table
function CachedDataFile:assume(index, entry)
    if (not self.assume_behaviour) or self.assume_behaviour.disabled then
        return
    end
    -- == "check" or == "checkfile"
    local current = self:getCached(index)
    local might, will = arrayfile_entry.entriesMightMatch(current, entry)
    if self.assume_behaviour.checkfile then
        if might and not will then -- if might is false, this won't change that.
            current = self:readEntry(index, "!")
            might, will = arrayfile_entry.entriesMightMatch(current, entry)
        end
    end
    if not might then
        error(
            "assumption was wrong: at index " ..
                index ..
                    "entry was " ..
                        self:formatEntry(current) .. ", it was assumed it would match " .. self:formatEntry(entry),
            2
        )
    end

    if self.assume_behaviour.update then
        self:updateReadCache(index, arrayfile_entry.entrySetMinus(entry, current))
    end
end

---write changes to base
---@return GenericDataFile
function CachedDataFile:commit()
    self.base:writeEntries(self.writecache)
    self.writecache = {}
    self.write_current_size = 0
    return self.base
end

---undo changes since last commit
---@return GenericDataFile
function CachedDataFile:rollback()
    self.writecache = {}
    self.write_current_size = 0
    self.readcache = {}
    self.read_current_size = 0
    return self.base
end

---makes a branch, which can be commited or rolled back.
---@return CachedDataFile
function CachedDataFile:branch()
    return CachedDataFile.make(self, math.huge, 10)
    -- -- todo
    -- return setmetatable(
    --     {
    --         parent = self,
    --         writecache = {}
    --     },
    --     BranchCachedDataFile
    -- )
end

--#region branch -- unused

--- a version that does not have a readcache
---@class BranchCachedDataFile: CachedDataFile
---@field parent CachedDataFile
---@field writecache table<integer,entry>
local BranchCachedDataFile = {}
setmetatable(
    BranchCachedDataFile,
    {
        __index = function(t, k) -- means attributes not redefined here are same as the original
            --this could lead to problems?
            return t.parent[k]
        end
    }
)

BranchCachedDataFile.isBranch = true
BranchCachedDataFile.readcache = false -- hopefully triggers errors when this is accessed (it's not supposed to be)
BranchCachedDataFile.__index = BranchCachedDataFile

BranchCachedDataFile.getCached = function(self, index)
    return arrayfile_entry.updatedEntry(self.parent:getCached(index), self.writecache[index])
end
BranchCachedDataFile.readEntry = function(self, index, keys)
    -- todo: now does not take into account if slf.writecache has some keys
    return arrayfile_entry.updatedEntry(self.parent:readEntry(index, keys), self.writecache[index])
end
BranchCachedDataFile.writeEntry = function(self, index, entry)
    self.writecache[index] = arrayfile_entry.updatedEntry(self.writecache[index], entry)
end
BranchCachedDataFile.commit = function(self)
    self.parent:writeEntries(self.writecache)
    self.writecache = {}
    return self.parent
end
BranchCachedDataFile.rollback = function(self)
    self.writecache = {}
    return self.parent
end
BranchCachedDataFile.updateReadCache = function(self, index, value)
    self.parent:updateReadCache(index, value) -- allowed for the sake of assume update
end
BranchCachedDataFile.flushWrites = function(self, saveToReadcache)
    return nil, "cannot flush branch"
end

BranchCachedDataFile.branch = CachedDataFile.branch
BranchCachedDataFile.readEntries = CachedDataFile.readEntries

BranchCachedDataFile.writeEntries = CachedDataFile.writeEntries

--#endregion branch

return CachedDataFile
