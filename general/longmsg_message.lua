-- code for receiving messages in many parts.
-- todo: confirm receive / request completion.
-- todo: set outOf to nil in most messages, then set it to a value in one. this way you can do 1/?, 2/?, 3/3
-- todo: pack multiple messages into fewer packets
local longmsg = {}

local event = require "event"
local component = require "component"
local serialization = require "serialization"

local config
if
  not pcall(
    function()
      config = require("filehelp").loadtable("/usr/cfgs/longmsg_message.cfg", true)
    end
  )
 then
  config = {
    position = {x = 0, y = 0, z = 0},
    default_port = 2400,
    default_address = nil
  }
end

---@alias Address string

longmsg.default_address = config.default_address

--- {x=,y=,z=}
longmsg.position = config.position

local modem = component.list("modem")()
if modem then
  longmsg.modem = component.proxy(modem)
end
local tunnel = component.list("tunnel")()
if tunnel then
  longmsg.tunnel = component.proxy(tunnel)
  longmsg.tunnelAddress = longmsg.tunnel.getChannel()
  if not longmsg.modem then
    longmsg.default_address = longmsg.tunnelAddress
  end
end

longmsg.default_port = config.default_port or 2400
if longmsg.modem then
  longmsg.modem.open(longmsg.default_port)
end

function longmsg.actualmessage(address, port, ...) -- leave address nil to broadcast
  address = address or longmsg.default_address
  if address then
    if address == longmsg.tunnelAddress then
      longmsg.tunnel.send(...)
    else
      longmsg.modem.send(address, port or longmsg.default_port, ...)
    end
  else
    if longmsg.modem then
      longmsg.modem.broadcast(port or longmsg.default_port, ...)
    end
  end
end

local helper = {}

function helper.slice(target, from, to, step)
  local sliced = {}
  for i = math.max(from or 1, 1), math.min(to or #target, #target), step or 1 do
    sliced[#sliced + 1] = target[i]
  end
  return sliced
end

function helper.splitSized(target, size)
  local amount = math.ceil(#target / size)
  local out = {}
  if type(target) == "string" then
    for i = 1, amount do
      table.insert(out, string.sub(target, (i - 1) * size + 1, i * size))
    end
  elseif type(target) == "table" then
    for i = 1, amount do
      table.insert(out, helper.slice(target, (i - 1) * size + 1, i * size))
    end
  end
  return out
end

function longmsg.sendmessage(name, msg, port, address) -- name: string, msg: string, port:int = longmsg.default_port, address: string = nil
  -- sends a message, in parts if necessary
  -- sends: "longmsg", id, i, outOf, name, message part
  local id = math.random()
  local maxsize = 8192 - 2 * 6 - 8 * 3 - #name - 3 - 10 -- 10 for good measure. also, should account for relays later.
  local spl = helper.splitSized(msg, maxsize)
  for i = 1, #spl do
    longmsg.actualmessage(address, port, "longmsg", id, i, #spl, name, spl[i])
  end
end

longmsg.messages = {} -- table of incomplete messages. could be local instead

longmsg.senderHistory = {} -- table of how many times an address has sent a longmsg message. not persistent

local function receivemessage(
  evt,
  localAddress,
  remoteAddress,
  port,
  distance,
  longmsgtag,
  id,
  i,
  outOf,
  name,
  messagePart)
  if evt ~= "modem_message" or longmsgtag ~= "longmsg" then
    return
  end
  local identifier = {remoteAddress, port, id} -- could change if relay?
  if not longmsg.messages[identifier] then
    longmsg.messages[identifier] = {}
  -- todo: set up timeout
  end
  local msi = longmsg.messages[identifier]
  msi[i] = messagePart
  for j = 1, outOf do -- return if not all parts are received
    if not msi[j] then
      return
    end
  end
  -- all parts are received
  longmsg.messages[identifier] = nil
  longmsg.senderHistory[remoteAddress] = (longmsg.senderHistory[remoteAddress] or 0) + 1
  event.push("longmsg_message", localAddress, remoteAddress, port, distance, name, table.concat(msi, ""))
end

function longmsg.setupDebug(x, y, width, height, evt) -- sets a box of given dimensions that listens to longmsg_message events. set evt to something else to listen to that instead
  -- todo: h,w
  local gpu = component.gpu
  local rx, ry = gpu.getResolution()
  width = width or rx - x
  height = height or ry - y
  return event.listen(
    evt or "longmsg_message",
    function(...)
      -- local extra = "" .. e .. " " .. localAddress .. " " .. remoteAddress .. " " .. port .. " " .. distance .. " " ..
      --                 name .. " "
      local message = ({...})[7]
      if evt then
        message = serialization.serialize({...}, 30)
      end
      local spl = helper.splitSized(message, width - 2) -- -2 for the borders
      for i = 1, math.min(#spl, height) do
        gpu.set(x, y + i - 1, "|" .. spl[i])
        gpu.set(x + width - 1, y + i - 1, "|")
      end
    end
  )
end

function longmsg.getSenderHistory()
  return longmsg.senderHistory
end

--- same as event.listen("longmsg_message",callback)
---@param callback fun(e, localAddress, remoteAddress, port, distance, name, message)
function longmsg.listen(callback)
  return event.listen("longmsg_message", callback)
end

---@class LongMessage
---@field localAddress Address
---@field remoteAddress Address
---@field port integer
---@field distance number
---@field name string
---@field message string

--- makes into a LongMessage
---@param e string
---@param localAddress Address
---@param remoteAddress Address
---@param port integer
---@param distance number
---@param name string
---@param message string
---@return LongMessage
local function makeTable(e, localAddress, remoteAddress, port, distance, name, message)
  if e ~= "longmsg_message" then
    error("not longmsg_message")
  end
  return {
    localAddress = localAddress,
    remoteAddress = remoteAddress,
    port = port,
    distance = distance,
    name = name,
    message = message
  }
end

--- inverse of makeClass
---@param longmessage LongMessage
---@return string, Address?, Address?, integer?, number?, string?, string?
local function tableToParams(longmessage)
  longmessage = longmessage or {}
  return "longmsg_message", longmessage.localAddress, longmessage.remoteAddress, longmessage.port, longmessage.distance, longmessage.name, longmessage.message
end
--- sees if longmessage fits the filter. nil is any
---@param longmessage LongMessage
---@param ops LongMessage
---@return boolean
local function compareFilter(longmessage, ops)
  for k, v in pairs(ops) do
    -- if type(v) == "string" then
    --   if not string.match(longmessage[k], v) then
    --     return false
    --   end
    -- else
    if longmessage[k] ~= v then
      return false
    end
    -- end
  end
  return true
end

--- wraps a function that accepts LongMessage
---@param func fun(longmessage: LongMessage)
---@return fun(e, localAddress, remoteAddress, port, distance, name, message)
local function wrapTableFunc(func)
  return function(...)
    return func(makeTable(...))
  end
end

--- like longmsg.listen, but with a LongMessage as argument
---@param callback fun(longmessage: LongMessage)
function longmsg.listenTable(callback)
  longmsg.listen(wrapTableFunc(callback))
end

--- todo
--- like event.pullFiltered
---@param filter fun(e, localAddress, remoteAddress, port, distance, name, message)
function longmsg.pullFiltered(filter)
  error("not implemented")
end

--- like event.pull
---@param ops table filter
---@param timeout? number seconds
---@return LongMessage
function longmsg.pullTable(ops, timeout)
  return makeTable(event.pull(timeout, tableToParams(ops)))
end

if not LONGMSG_INITIALIZED then -- global
  event.listen("modem_message", receivemessage)
  LONGMSG_INITIALIZED = true
end

return longmsg
