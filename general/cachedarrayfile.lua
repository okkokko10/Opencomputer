local arrayfile = require("arrayfile")
local Helper = require("Helper")

---@class cachedarrayfile: arrayfile
---@field writecache table<integer,entry>
---@field readcache table<integer,entry> -- if an entry exists, it is guaranteed to be up to date with writecache, and not have any more holes than writecache
---@field write_current_size integer
---@field read_current_size integer
---@field write_max_size integer
---@field read_max_size integer
---@field assume_behaviour boolean? -- if truthy, enables assume
---@field private flush_suppressors table -- if nonempty, flush is suppressed
local cachedarrayfile = setmetatable({}, arrayfile)

cachedarrayfile.__index = cachedarrayfile

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
    arrf.flush_suppressors = setmetatable({},{__mode="k"})
    return setmetatable(arrf, cachedarrayfile)
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry table
function cachedarrayfile:writeEntry(index, entry)
    local original = self.writecache[index]
    if not original then
        original = self:makeEntry({}, index)
        self.writecache[index] = original
        self.write_current_size = self.write_current_size + 1
    end
    arrayfile.updateEntry(original, entry)
    local cached = self.readcache[index]
    if cached then
        arrayfile.updateEntry(cached, entry)
    end
    self:checkCacheSize()
end

---returns an object that suppresses this from flushing until it gets `finish` called (or it is garbage collected)
---@return { finish:  fun() } suppressor
function cachedarrayfile:suppressFlush()
    local suppressor
    suppressor = {finish = function ()
        self.flush_suppressors[suppressor] = nil
    end}
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
        if saveToReadcache and not self.readcache[index] then
            self.readcache[index] = entry
            self.read_current_size = self.read_current_size + 1
        end
        arrayfile.writeEntry(self, index, arrayfile.entryHolesFilled(entry, self.readcache[index])) -- since a readcache element is up to date with writecache when it exists, this might avoid unnecessary seeking
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
---if keys is true or nil, get all values
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys true|nil|string|string[]
---@return entry entry
function cachedarrayfile:readEntry(index, keys)
    local cached = self.readcache[index] or self.writecache[index]
    if cached then
        if keys == true or keys == nil then
            keys = self.nameList
        else
            keys = arrayfile.splitArgString(keys)
        end
        local works = true
        for i = 1, #keys do
            if cached[keys[i]] == nil then
                works = false
                break
            end
        end
        if works then
            return cached
        end
    end

    local entry = self:readEntryDirect(index)
    if self.writecache[index] then
        arrayfile.updateEntry(entry, self.writecache[index]) -- update loaded entry with cached, not yet saved changes
    end
    if not self.readcache[index] then
        self.read_current_size = self.read_current_size + 1
        self:checkCacheSize()
    end
    self.readcache[index] = entry
    return entry
end

---warning: causes undefined behaviour if the input data is wrong.
---updates the entry in the readcache. this does not write to the array directly.
---works as an assertion if the data happens to already be cached: check if this matches it.
---tip: partially read entries' unread values are nil, so using them here works
---@param index integer
---@param entry table
function cachedarrayfile:assume(index, entry)
    if not self.assume_behaviour then
        return
    end
    local original = self.readcache[index]
    if not original then
        original = self:makeEntry({}, index)
        self.readcache[index] = original
        self.read_current_size = self.read_current_size + 1
        local write = self.writecache[index]
        if write then
            arrayfile.updateEntry(original, write)
        end
    end
    arrayfile.updateEntrySubsetCheck(original, entry)
end

return cachedarrayfile
