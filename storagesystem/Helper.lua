local unicode = require("unicode")
local fs = require("filesystem")
local serialization = require("serialization")
local event = require("event")

local Helper = {}

--- copied from edit.lua
---@param filename string
---@param buffer table
local function savef2(filename, buffer)
  local file_parentpath = fs.path(filename)

  local new = not fs.exists(filename)
  local backup -- presumably this is: find the smallest name filename~x that is not taken, and backup to it
  if not new then
    backup = filename .. "~"
    for i = 1, math.huge do
      if not fs.exists(backup) then
        break
      end
      backup = filename .. "~" .. i
    end
    fs.copy(filename, backup)
  end
  if not fs.exists(file_parentpath) then
    fs.makeDirectory(file_parentpath)
  end
  local f, reason = io.open(filename, "w")
  if f then
    local chars, firstLine = 0, true
    for _, bline in ipairs(buffer) do
      if not firstLine then
        bline = "\n" .. bline
      end
      firstLine = false
      f:write(bline)
      chars = chars + unicode.len(bline)
    end
    f:close()
  else
    -- setStatus(reason)
  end
  if not new then
    fs.remove(backup)
  end
end

--- copied from edit.lua
---@param filename string
---@return table
local function loadf2(filename)
  local buffer = {}
  local f = io.open(filename)
  if f then
    -- local x, y, w, h
    -- local chars = 0
    for fline in f:lines() do
      table.insert(buffer, fline)
      -- chars = chars + unicode.len(fline)
      -- if #buffer <= h then
      --     -- drawLine(x, y, w, h, #buffer)
      -- end
    end
    f:close()
    if #buffer == 0 then
      table.insert(buffer, "")
    end
  else
    table.insert(buffer, "")
  end
  return buffer
end

Helper.filecache = {}

-- maybe this should go in a config file
Helper.DO_CACHE = true

-- autosave period in seconds that starts when this program is loaded.
Helper.AUTOSAVE_DEFAULT = 10

---@param filename string
---@param buffer table
function Helper.savef(filename, buffer, trulySave)
  if trulySave or not Helper.DO_CACHE then
    savef2(filename, buffer)
    return
  end
  Helper.filecache[filename] = buffer
end

---@param filename string
---@return table
function Helper.loadf(filename, trulyLoad)
  if trulyLoad or not Helper.DO_CACHE then
    return loadf2(filename)
  end
  local cached = Helper.filecache[filename]
  if not cached then
    cached = loadf2(filename)
    Helper.filecache[filename] = cached
  end
  return cached
end

--- commits cached changes to files.
function Helper.saveCache()
  for filename, buffer in pairs(Helper.filecache) do
    savef2(filename, buffer)
  end
end
--- clears the cache, allowing outside edits to modify.
---@param filename string|nil leave empty to clear the entire cache
function Helper.clearCache(filename)
  if filename then
    Helper.filecache[filename] = nil
  else
    Helper.filecache = {}
  end
end

local autosaveListener = nil

function Helper.autosaveSetup(seconds)
  Helper.autosaveCancel()
  autosaveListener = event.timer(seconds, Helper.saveCache, math.huge)

end
function Helper.autosaveCancel()
  if autosaveListener then
    event.cancel(autosaveListener)
    autosaveListener = nil
  end
end

if Helper.AUTOSAVE_DEFAULT > 0 then
  Helper.autosaveSetup(Helper.AUTOSAVE_DEFAULT)
end

--- map
---@param target table
---@param fun function
function Helper.map(target, fun)
  local out = {}
  for key, value in ipairs(target) do
    out[key] = fun(value, key)
  end
  return out
end
--- map. if k' is nil, the entry is filtered out 
---@param target table
---@param fun function (v,k) => v',k'
function Helper.mapWithKeys(target, fun)
  local out = {}
  for key, value in pairs(target) do
    local v, k = fun(value, key)
    if k then
      out[k] = v
    end
  end
  return out
end
--- map. maps to indices 1...n. does not preserve order.
---@param target table
---@param fun function (v,k) => v'
function Helper.mapIndexed(target, fun)
  local out = {}
  for key, value in pairs(target) do
    out[#out + 1] = fun(value, key)
  end
  return out
end

--- loads a table of tables from a file, with their element keyname="id" determining their index.
---@param filepath string
---@param keyname string|integer|nil
---@return table
function Helper.loadCSV(filepath, keyname)
  keyname = keyname or "id"
  local amount = 0 -- unimplemented
  return Helper.mapWithKeys(Helper.loadf(filepath), function(line)
    local out = serialization.unserialize(line) -- empty file
    amount = amount + 1
    return out, out and out[keyname]
  end)
end

--- saves a table of tables to a file. Does not guarantee any particular order.
---@param target table
---@param filepath string
function Helper.saveCSV(target, filepath)
  Helper.savef(filepath, Helper.mapIndexed(target, function(one)
    return serialization.serialize(one)
  end))

end

--- makes a shallow string from the inputs
function Helper.makeIndex(...)
  return table.concat({...}, "~")
end
--- makes a shallow string from the target, only taking into account values between start and finish
---@param target table
---@param start integer
---@param finish integer
function Helper.makeIndexBetween(target, start, finish)
  -- todo: does not work for non string|number
  return table.concat(target, "~", start, finish)
end

--- flattens a table of tables
---@param supertable table
---@param out table|nil if provided, is appended to
function Helper.flatten(supertable, out)
  out = out or {}
  local i = #out + 1
  for y = 1, #supertable do
    local t = supertable[y]
    if type(t) ~= "table" then
      print(serialization.serialize(supertable))
    end
    for x = 1, #t do
      out[i] = t[x]
      i = i + 1
    end
  end
  return out

end

--- find an element and index that fits the condition
---@param target table
---@param condition function
---@return any|nil
---@return any|nil
function Helper.find(target, condition)
  for k, v in pairs(target) do
    if condition(v, k) then
      return v, k
    end
  end
end

return Helper
