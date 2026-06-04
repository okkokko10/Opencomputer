
peripheral.find("modem", rednet.open)


-- local authorized = {} 
-- for index, value in ipairs({...}) do
--     authorized[value] = true
-- end
-- local pretty = require "cc.pretty"
-- print("authorized: ")
-- pretty.pretty_print(authorized)


local pretty = require "cc.pretty"

local remote = {}
local host = {}


-- has side effects
local function getOffset(wind)
    wind.setCursorPos(1,1)
    return term.native().getCursorPos()
end
--- functions that return values don't wait for the remote to respond.
--- instead the host has a copy of the redirect


---@class RedirectHost
---@field hostcopy table
---@field send fun(func: any, ...)
local RedirectHost = {__name = "RedirectHost"}

function RedirectHost.__index(self,key)
    return function (...)
        self.send(key,...)
        return self.hostcopy[key](...)
    end
end


function host.new_redirect(receiver, parent, nX, nY, nWidth, nHeight)
    local hostcopy = window.create(parent,nX,nY,nWidth,nHeight) -- maybe just use parent?
    local ox, oy = getOffset(hostcopy)
    return setmetatable({
        hostcopy = hostcopy,
        send = function (key,...)
            rednet.send(receiver,{func=key,args={...}},"redirect_remote_render")
        end,
        ox = ox, oy = oy
    },RedirectHost)
end


function remote.render_received(target, message)
    pcall(target[message.func],unpack(message.args))
    -- target[message.func](unpack(message.args))
end



function remote.listen(remoteData)
    while true do
        local sender, message = rednet.receive("redirect_remote_render")
        if remoteData.hostID and remoteData.hostID == sender then
            remote.render_received(remoteData.window,message)
        end
    end
end


--- RemoteData
--- HostData
--- to store data like the position adjustment


--- todo: make it so monitors can be used with this.
--- todo: resize the host
--- 
--- in parallel, all threads get the same os.pullEvent
--- do events queued from parallel threads go upstream? yes.
--- 


local function mouse_adjust(tEvent,data)
    local d = data.isHost and 1 or -1
    -- print(dx, dy, isReceived)
    local xAdjust = d*data.ox
    local yAdjust = d*data.oy
    return {tEvent[1],tEvent[2],tEvent[3]+xAdjust,tEvent[4]+yAdjust}
end

--- todo: if the value is a function, use it to change the value.
local sendable_events = {
    ["char"] = true,
    -- ["file_transfer"] = true,
    ["key"] = true,
    ["key_up"] = true,
    ["mouse_click"] = mouse_adjust,
    ["mouse_drag"] = mouse_adjust,
    ["mouse_scroll"] = mouse_adjust,
    ["mouse_up"] = mouse_adjust,
    ["paste"] = true,
}

function remote.send_events(remoteData)
    while true do
        local tEvent = table.pack(os.pullEvent())
        local event = tEvent[1]
        local te = sendable_events[event]
        if te then
            if te ~= true then
                tEvent = te(tEvent,remoteData)
            end
            rednet.send(remoteData.hostID,tEvent,"redirect_remote_event")
        end
    end
end



function host.event_received(message,hostData)
    local te = sendable_events[message[1]]
    if te and te ~= true then
        message = te(message,hostData)
    end
    os.queueEvent(unpack(message))
end
function host.listen_events(remoteID,wind)
    
    local hostData = {isHost=true,remoteID = remoteID,window = wind.hostcopy, send_window = wind, ox = wind.ox, oy = wind.oy}
    while true do
        local sender, message = rednet.receive("redirect_remote_event")
        if remoteID and remoteID == sender then
            host.event_received(message,hostData)
        end
    end
end



function remote.hook(hostID,wind)
    local ox, oy = getOffset(wind)
    local remoteData = {isHost=false,hostID = hostID,window = wind, ox = ox, oy = oy}
    parallel.waitForAny(
    function ()
        remote.listen(remoteData)
    end,
    function ()
        remote.send_events(remoteData)
    end
    )
end



-- while true do 
--     local sender, message, protocol = rednet.receive("redirect_remote")
--     if authorized[tostring(sender)] then
--         print("command received: ", message)
--         shell.run(message)
--     end
    
-- end

return {host = host, remote = remote,
    nWidth = 20,
    nHeight = 20
}