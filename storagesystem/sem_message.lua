-- code for receiving messages in many parts.
-- todo: confirm receive / request completion.
-- todo: set outOf to nil in most messages, then set it to a value in one. this way you can do 1/?, 2/?, 3/3
-- todo: pack multiple messages into fewer packets
local sem = {}

local event = require "event"
local component = require "component"

sem.default_address = nil

local modem = component.list("modem")()
if modem then
  sem.modem = component.proxy(modem)
end
local tunnel = component.list("tunnel")()
if tunnel then
  sem.tunnel = component.proxy(tunnel)
  sem.tunnelAddress = sem.tunnel.getChannel()
  if not sem.modem then
    sem.default_address = sem.tunnelAddress
  end
end

sem.default_port = 2400
if sem.modem then
  sem.modem.open(sem.default_port)
end

function sem.actualmessage(address, port, ...) -- leave address nil to broadcast
  address = address or sem.default_address
  if address then
    if address == sem.tunnelAddress then
      sem.tunnel.send(...)
    else
      sem.modem.send(address, port or sem.default_port, ...)
    end
  else
    if sem.modem then
      sem.modem.broadcast(port or sem.default_port, ...)
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

function sem.sendmessage(name, msg, port, address) -- name: string, msg: string, port:int = sem.default_port, address: string = nil
  -- sends a message, in parts if necessary
  -- sends: "sem", id, i, outOf, name, message part
  local id = math.random()
  local maxsize = 8192 - 2 * 6 - 8 * 3 - #name - 3 - 10 -- 10 for good measure. also, should account for relays later.
  local spl = helper.splitSized(msg, maxsize)
  for i = 1, #spl do
    sem.actualmessage(address, port, "sem", id, i, #spl, name, spl[i])
  end
end

sem.messages = {} -- table of incomplete messages. could be local instead

sem.senderHistory = {} -- table of how many times an address has sent a sem message. not persistent

local function receivemessage(evt, localAddress, remoteAddress, port, distance, semtag, id, i, outOf, name, messagePart)
  if evt ~= "modem_message" or semtag ~= "sem" then
    return
  end
  local identifier = {remoteAddress, port, id} -- could change if relay?
  if not sem.messages[identifier] then
    sem.messages[identifier] = {}
    -- todo: set up timeout
  end
  local msi = sem.messages[identifier]
  msi[i] = messagePart
  for j = 1, outOf do -- return if not all parts are received
    if not msi[j] then
      return
    end
  end
  -- all parts are received
  sem.messages[identifier] = nil
  sem.senderHistory[remoteAddress] = (sem.senderHistory[remoteAddress] or 0) + 1
  event.push("sem_message", localAddress, remoteAddress, port, distance, name, table.concat(msi, ""))
end

function sem.setupDebug(x, y, width, height, evt) -- sets a box of given dimensions that listens to sem_message events. set evt to something else to listen to that instead
  -- todo: h,w
  local gpu = component.gpu
  local rx, ry = gpu.getResolution()
  width = width or rx - x
  height = height or ry - y
  return event.listen(evt or "sem_message", function(e, localAddress, remoteAddress, port, distance, name, message)
    local extra = "" .. e .. " " .. localAddress .. " " .. remoteAddress .. " " .. port .. " " .. distance .. " " ..
                    name .. " "
    local spl = helper.splitSized(message, width - 2) -- -2 for the borders
    for i = 1, math.min(#spl, height) do
      gpu.set(x, y + i - 1, "|" .. spl[i])
      gpu.set(x + width - 1, y + i - 1, "|")
    end
  end)
end

function sem.getSenderHistory()
  return sem.senderHistory
end

if not SEM_INITIALIZED then -- global
  event.listen("modem_message", receivemessage)
  SEM_INITIALIZED = true
end

return sem
