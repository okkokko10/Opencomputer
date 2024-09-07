local arrayfile = require("arrayfile")
local arrayfile_entry = require("arrayfile_entry")
local Helper = require("Helper")

---@class cachedarrayfile: arrayfile
---@field writecache table<integer,entry>
---@field readcache table<integer,entry> -- if an entry exists, it is guaranteed to be up to date with writecache, and not have any more holes than writecache
---@field write_current_size integer
---@field read_current_size integer
---@field write_max_size integer
---@field read_max_size integer
---@field assume_behaviour { disabled: boolean?, check: boolean?, checkfile: boolean?, update: boolean? }? -- assume options
---@field private flush_suppressors table -- if nonempty, flush is suppressed
local cachedarrayfile = setmetatable({}, arrayfile)

cachedarrayfile.__index = cachedarrayfile

cachedarrayfile.super = arrayfile

---creates a new cachedarrayfile object
---@param filename string
---@param nameList? string[] |string
---@param formats? string[] |string -- sequence or space/punctuation-separated string.pack format strings
---@param write_max_size? integer = 1000
---@param read_max_size? integer = 1000
function cachedarrayfile.make(filename, nameList, formats, write_max_size, read_max_size)
    local arrf = arrayfile.make(filename, nameList, formats)
    ---@cast arrf cachedarrayfile
    arrf.writecache = {}
    arrf.write_current_size = 0
    arrf.write_max_size = write_max_size or 1000
    arrf.readcache = {}
    arrf.read_current_size = 0
    arrf.read_max_size = read_max_size or 1000
    arrf.flush_suppressors = setmetatable({}, {__mode = "k"})
    return setmetatable(arrf, cachedarrayfile)
end

function cachedarrayfile:getReadCache(index)
    return self.readcache[index]
end

function cachedarrayfile:setReadCache(index, value)
    if self.readcache[index] == nil then
        self.write_current_size = self.write_current_size + 1
    end
    if value == nil then
        self.write_current_size = self.write_current_size - 1
    end
    self.readcache[index] = value
end

function cachedarrayfile:updateReadCacheIfExists(index, value)
    local old = self:getReadCache(index)
    if old then
        self:setReadCache(index, arrayfile_entry.updatedEntry(old, value))
    end
end
function cachedarrayfile:updateReadCache(index, value)
    self:setReadCache(index, arrayfile_entry.updatedEntry(self:getReadCache(index), value))
end
function cachedarrayfile:setReadCacheUnlessExists(index, value)
    local old = self:getReadCache(index)
    if not old then
        self:setReadCache(index, value)
    end
end

function cachedarrayfile:getWriteCache(index)
    return self.writecache[index]
end

function cachedarrayfile:setWriteCache(index, value)
    if self.writecache[index] == nil then
        self.write_current_size = self.write_current_size + 1
    end
    if value == nil then
        self.write_current_size = self.write_current_size - 1
    end
    self.writecache[index] = value
end

function cachedarrayfile:updateWriteCache(index, value)
    self:setWriteCache(index, arrayfile_entry.updatedEntry(self:getWriteCache(index), value))
end

---get a cached entry
---@param index integer
---@return entry?
function cachedarrayfile:getCached(index)
    return self:getReadCache(index) or self:getWriteCache(index)
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function cachedarrayfile:writeEntry(index, entry)
    self:updateWriteCache(index, entry)
    self:updateReadCacheIfExists(index, entry)
    self:checkCacheSize()
end

---returns an object that suppresses this from flushing until it gets `finish` called (or it is garbage collected)
---@return { finish:  fun() } suppressor
function cachedarrayfile:suppressFlush()
    local suppressor
    suppressor = {
        finish = function()
            self.flush_suppressors[suppressor] = nil
        end
    }
    self.flush_suppressors[suppressor] = true
    return suppressor
end

function cachedarrayfile:isFlushSuppressed()
    return next(self.flush_suppressors) ~= nil
end

---flushes writes to the file. if saveToReadcache is true, the writecache is transferred to readcache instead of disappearing.
---@param saveToReadcache boolean?
function cachedarrayfile:flushWrites(saveToReadcache)
    if self:isFlushSuppressed() then
        return nil, "suppressed"
    end
    -- essentially arrayfile:writeEntries
    for index, entry in Helper.sortedpairs(self.writecache) do
        if saveToReadcache then
            self:setReadCacheUnlessExists(index, entry)
        end
        self.super.writeEntry(self, index, self.super.entryHolesFilled(entry, self:getReadCache(index))) -- since a readcache element is up to date with writecache when it exists, this might avoid unnecessary seeking
    end
    self.writecache = {}
    self.write_current_size = 0
    self:closeWrite()
    return true
end

---if caches are too large, flush/clear them.
function cachedarrayfile:checkCacheSize()
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

function cachedarrayfile:clearReadcache()
    self.readcache = {}
    self.read_current_size = 0
end

---only retrieves the stated keys if they are cached.
---if keys is false or nil, get all values
---if keys is "!", ignore cached.
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys false|nil|string|string[]
---@return entry entry
function cachedarrayfile:readEntry(index, keys)
    if keys ~= "!" then
        local cached = self:getCached(index)
        if cached then
            if not keys then
                keys = self.nameList
            else
                keys = arrayfile.splitArgString(keys)
            end
            if arrayfile_entry.entryHasKeys(cached, keys) then
                return cached
            end
        end
    end

    local entry = self:readEntryDirect(index)
    -- arrayfile.updateEntry(entry, self.writecache[index]) -- update loaded entry with cached, not yet saved changes
    self:checkCacheSize()
    self:setReadCache(index, entry)

    return self:getCached(index) or error()
end

---warning: causes undefined behaviour if the input data is wrong.
---updates the entry in the readcache. this does not write to the array directly.
---works as an assertion if the data happens to already be cached: check if this matches it.
---tip: partially read entries' unread values are nil, so using them here works
---@param index integer
---@param entry table
function cachedarrayfile:assume(index, entry)
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

function cachedarrayfile:commit()
    error("cannot commit the main")
end

function cachedarrayfile:rollback()
    error("cannot rollback the main")
end
local BranchCachedArrayFile
---comment
---@return cachedarrayfile
function cachedarrayfile:branch()
    -- todo
    return setmetatable(
        {
            parent = self,
            writecache = {}
        },
        BranchCachedArrayFile
    )
end

---@class BranchCachedArrayFile: cachedarrayfile
---@field parent cachedarrayfile
---@field writecache table<integer,entry>
BranchCachedArrayFile =
    setmetatable(
    {
        isBranch = true,
        readcache = false, -- hopefully triggers errors when this is accessed (it's not supposed to be)
        __index = BranchCachedArrayFile,
        getCached = function(self, index)
            return arrayfile_entry.updatedEntry(self.parent:getCached(index), self.writecache[index])
        end,
        readEntry = function(self, index, keys)
            -- todo: now does not take into account if slf.writecache has some keys
            return arrayfile_entry.updatedEntry(self.parent:readEntry(index, keys), self.writecache[index])
        end,
        writeEntry = function(self, index, entry)
            self.writecache[index] = arrayfile_entry.updatedEntry(self.writecache[index], entry)
        end,
        commit = function(self)
            self.parent:writeEntries(self.writecache)
            self.writecache = {}
            return self.parent
        end,
        rollback = function(self)
            self.writecache = {}
            return self.parent
        end,
        branch = cachedarrayfile.branch,
        readEntries = cachedarrayfile.readEntries,
        writeEntries = cachedarrayfile.writeEntries,
        updateReadCache = function(self, index, value)
            self.parent:updateReadCache(index, value) -- allowed for the sake of assume update
        end,
        flushWrites = function(self, saveToReadcache)
            return nil, "cannot flush branch"
        end
    },
    {
        __index = function(t, k) -- means attributes not redefined here are same as the original
            --this could lead to problems?
            return t.parent[k]
        end
    }
)

return cachedarrayfile
