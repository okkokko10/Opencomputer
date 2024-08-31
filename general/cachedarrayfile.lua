local arrayfile = require("arrayfile")
local Helper = require("Helper")

---@class cachedarrayfile: arrayfile
---@field writecache table<integer,entry>
---@field readcache table<integer,entry> -- if an entry exists, it is guaranteed to be up to date with writecache, and not have any more holes than writecache
---@field write_current_size integer
---@field read_current_size integer
---@field write_max_size integer
---@field read_max_size integer
local cachedarrayfile = setmetatable({}, arrayfile)

---creates a new cachedarrayfile object
---@param filename string
---@param formats string[] |string -- sequence or space/punctuation-separated string.pack format strings
---@param nameList string[] |string
---@param write_max_size? integer = 1000
---@param read_max_size? integer = 1000
function cachedarrayfile.make(filename, formats, nameList, write_max_size, read_max_size)
    local arrf = arrayfile.make(filename, formats, nameList)
    ---@cast arrf cachedarrayfile
    arrf.writecache = {}
    arrf.write_current_size = 0
    arrf.write_max_size = write_max_size or 1000
    arrf.readcache = {}
    arrf.read_current_size = 0
    arrf.read_max_size = read_max_size or 1000
    return setmetatable(arrf, cachedarrayfile)
end

---writes entry to index. if some values are blank, they are left as is
---@param index integer
---@param entry entry
function cachedarrayfile:writeEntry(index, entry)
    local original = self.writecache[index]
    if not original then
        original = setmetatable({}, self.entryMetatable)
        self.writecache[index] = original
        self.write_current_size = self.write_current_size + 1
    end
    arrayfile.updateEntry(original, entry)
    local cached = self.readcache[index]
    if cached then
        arrayfile.updateEntry(cached, entry)
    end
end
---flushes writes to the file. if saveToReadcache is true, the writecache is transferred to readcache instead of disappearing.
---@param saveToReadcache boolean?
function cachedarrayfile:flushWrites(saveToReadcache)
    -- essentially arrayfile:writeEntries
    for index, entry in Helper.sortedpairs(self.writecache) do
        if saveToReadcache and not self.readcache[index] then
            self.readcache[index] = entry
            self.read_current_size = self.read_current_size + 1
        end
        arrayfile.writeEntry(self, index, self.readcache[index] or entry) -- since a readcache element is up to date with writecache when it exists, this might avoid unnecessary seeking
    end
    self.writecache = {}
    self.write_current_size = 0
end

---if caches are too large, flush/clear them.
function cachedarrayfile:checkSize()
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

---readEntry, except it only retrieves the stated keys
---if only some of the entry's values are cached, if only they are requested, the non-cached values won't be retrieved
---@param index integer
---@param keys string|string[]
---@return entry entry
function cachedarrayfile:readEntryValues(index, keys)
    keys = arrayfile.splitArgString(keys)
    local cached = self.readcache[index] or self.writecache[index]
    if cached then
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

    local entry = self:readEntry(index)
    if self.writecache[index] then
        arrayfile.updateEntry(entry, self.writecache[index]) -- update loaded entry with cached, not yet saved changes
    end
    if not self.readcache[index] then
        self.read_current_size = self.read_current_size + 1
    end
    self.readcache[index] = entry
    return entry
end

return cachedarrayfile
