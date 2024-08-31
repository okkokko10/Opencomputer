local unicode = require("unicode")
local fs = require("filesystem")
local serialization = require("serialization")
local event = require("event")

local Helper = {}

--- map
---@generic K,V,R
---@param target table<K,V>
---@param fun fun(value:V,key:K):R
---@return table<K,R>
function Helper.map(target, fun)
  local out = {}
  for key, value in pairs(target) do
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

function Helper.splitString(str, pattern)
  local i, j = string.find(str, pattern)
  if i then
    return string.sub(str, 1, i - 1), Helper.splitString(string.sub(str, j + 1), pattern)
  else
    return str
  end
end

--- makes a string from the inputs
function Helper.makeIndex(...)
  return serialization.serialize({...})
end
--- unpacks a value from Helper.makeIndex
---@param index string
function Helper.undoIndex(index)
  return table.unpack(serialization.unserialize(index))
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

--- gets the value and key that result in the smallest output of fun. if all return math.huge, then returns nil
---@generic K,V
---@param target table<K,V>
---@param fun fun(v:V,k:K):number? -- return math.huge or nil to ignore
---@param enough? number -- if a value less than or equal to this is found, it is returned early
---@return V|nil
---@return K|nil
function Helper.min(target, fun, enough)
  local current_points = math.huge
  local current_value = nil
  local current_key = nil
  for k, v in pairs(target) do
    local points = fun(v, k)
    if points and points < current_points then
      current_value = v
      current_key = k
      if enough and current_value <= enough then
        break
      end
    end
  end
  return current_value, current_key
end

function Helper.shallowCopy(target)
  return table.move(target, 1, #target, 1, {})
end

---if num is larger than mod, splits it into multiple numbers that are at most mod, and greater than 0.
---all but the last element are equal to mod, and the last is the remainder (unless 0)
---optionally first lets the first element be a different size.
---@param num number
---@param mod number
---@param first? number
---@return number[]
function Helper.splitNumber(num, mod, first)
  assert(mod > 0)
  if num <= 0 then
    if num < 0 then
      error("num cannot be negative")
    end
    return {}
  end
  local out = {}
  if first and first > 0 then
    out[1] = math.min(first, num)
    num = num - out[1]
  end

  while num > mod do
    out[#out + 1] = mod
    num = num - mod
  end
  if num > 0 then
    out[#out + 1] = num
  end
  return out
end

---gets the indices of the table
---@param tbl table
---@return table
function Helper.indices(tbl)
  local indices = {}
  for index, _ in pairs(tbl) do
    indices[#indices + 1] = index
  end
  return indices
end

---an iterator for for.
---@param tbl table
---@return function next
---@return table tbl
---@return nil
function Helper.sortedpairs(tbl)
  local indices = Helper.indices(tbl)
  table.sort(indices) -- todo: does this work?
  local i = 1
  return function(tble, oldindex)
    local index = indices[i]
    i = i + 1
    return index, tble[index]
  end, tbl, nil
end

return Helper
