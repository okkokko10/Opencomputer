local fs = require("filesystem")
local unicode = require("unicode")
local serialization = require("serialization")
local event = require("event")
local Helper = require("Helper")

local filehelp = {}

-- function filehelp.get(db, index)
--   return
-- end

-- function filehelp.load(filename)

-- end

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

filehelp.filecache = {}

-- maybe this should go in a config file
filehelp.DO_CACHE = true

-- autosave period in seconds that starts when this program is loaded.
filehelp.AUTOSAVE_DEFAULT = 10

---@param filename string
---@param buffer table
function filehelp.savef(filename, buffer, trulySave)
  if trulySave or not filehelp.DO_CACHE then
    savef2(filename, buffer)
    return
  end
  filehelp.filecache[filename] = buffer
end

---@param filename string
---@return table
function filehelp.loadf(filename, trulyLoad)
  if trulyLoad or not filehelp.DO_CACHE then
    return loadf2(filename)
  end
  local cached = filehelp.filecache[filename]
  if not cached then
    cached = loadf2(filename)
    filehelp.filecache[filename] = cached
  end
  return cached
end

function filehelp.loadtable(filename, trulyLoad)
  return serialization.unserialize(table.concat(filehelp.loadf(filename, trulyLoad), "\n"))
end

--- commits cached changes to files.
function filehelp.saveCache()
  for filename, buffer in pairs(filehelp.filecache) do
    savef2(filename, buffer)
  end
end
--- clears the cache, allowing outside edits to modify.
---@param filename string|nil leave empty to clear the entire cache
function filehelp.clearCache(filename)
  if filename then
    filehelp.filecache[filename] = nil
  else
    filehelp.filecache = {}
  end
end

local autosaveListener = nil

function filehelp.autosaveSetup(seconds)
  filehelp.autosaveCancel()
  autosaveListener = event.timer(seconds, filehelp.saveCache, math.huge)

end
function filehelp.autosaveCancel()
  if autosaveListener then
    event.cancel(autosaveListener)
    autosaveListener = nil
  end
end

if filehelp.AUTOSAVE_DEFAULT > 0 then
  filehelp.autosaveSetup(filehelp.AUTOSAVE_DEFAULT)
end

--- loads a table of tables from a file, with their element keyname="id" determining their index.
---@param filepath string
---@param keyname string|integer|nil
---@return table
function filehelp.loadCSV(filepath, keyname)
  keyname = keyname or "id"
  local amount = 0 -- unimplemented
  return Helper.mapWithKeys(filehelp.loadf(filepath), function(line)
    local out = serialization.unserialize(line) -- empty file
    amount = amount + 1
    return out, out and out[keyname]
  end)
end

--- saves a table of tables to a file. Does not guarantee any particular order.
---@param target table
---@param filepath string
function filehelp.saveCSV(target, filepath)
  filehelp.savef(filepath, Helper.mapIndexed(target, function(one)
    return serialization.serialize(one)
  end))

end

return filehelp
