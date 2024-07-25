-- code for receiving messages in many parts.
-- todo: confirm receive / request completion.
-- todo: set outOf to nil in most messages, then set it to a value in one. this way you can do 1/?, 2/?, 3/3
-- todo: pack multiple messages into fewer packets
local longmsg = {}

local event = require "event"
local component = require "component"

local config = require("filehelp").loadtable("/usr/cfgs/longmsg_message.cfg", true)

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

local function receivemessage(evt, localAddress, remoteAddress, port, distance, longmsgtag, id, i, outOf, name,
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
  return event.listen(evt or "longmsg_message", function(e, localAddress, remoteAddress, port, distance, name, message)
    local extra = "" .. e .. " " .. localAddress .. " " .. remoteAddress .. " " .. port .. " " .. distance .. " " ..
                    name .. " "
    local spl = helper.splitSized(message, width - 2) -- -2 for the borders
    for i = 1, math.min(#spl, height) do
      gpu.set(x, y + i - 1, "|" .. spl[i])
      gpu.set(x + width - 1, y + i - 1, "|")
    end
  end)
end

function longmsg.getSenderHistory()
  return longmsg.senderHistory
end

if not longmsg_INITIALIZED then -- global
  event.listen("modem_message", receivemessage)
  longmsg_INITIALIZED = true
end

return longmsg
