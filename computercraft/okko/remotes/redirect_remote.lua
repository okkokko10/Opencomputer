
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

--- todo: if the value is a function, use it to change the value. also if it returns nil, an event is not sent.
local sendable_events = {
    ["char"] = function(tEvent,data)
        -- listens for ä press, and terminates if so
        if tEvent[2] == "ä" then
            -- return table.pack("terminate", true)
        else
            return tEvent
        end 

    end,
    -- ["file_transfer"] = true,
    ["key"] = 
    function(tEvent,data)
        -- listens for ä press, and terminates if so
        if tEvent[2] == 39 then
            return table.pack("terminate", true)
        else
            return tEvent
        end
    end,
    ["key_up"] = true,
    ["mouse_click"] = mouse_adjust,
    ["mouse_drag"] = mouse_adjust,
    ["mouse_scroll"] = mouse_adjust,
    ["mouse_up"] = mouse_adjust,
    ["paste"] = true,
    ["terminate"] = function (tEvent,data)
        if data.isHost then
            return tEvent
        end

    end
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
            if tEvent then
                rednet.send(remoteData.hostID,tEvent,"redirect_remote_event")
            end
        end
    end
end



function host.event_received(message,hostData)
    local te = sendable_events[message[1]]
    if te and te ~= true then
        message = te(message,hostData)
    end
    if multishell then
        multishell.setFocus(multishell.getCurrent())
    end
    if message then
        os.queueEvent(unpack(message))
    end
end
function host.listen_events(hostData)
    while true do
        
        local res, sender, message = pcall(rednet.receive,"redirect_remote_event")
        if hostData.remoteID and hostData.remoteID == sender then
            host.event_received(message,hostData)
        end
    end
end

function remote.open(remoteData)
    term.clear()
    term.write("connection opening...")
    local height, width = remoteData.window.getSize()
    rednet.send(remoteData.hostID,{height=height,width=width},"redirect_remote_open_remote")
end

function host.listen_open(hostData)
    while true do
        local res, sender, message = pcall(rednet.receive,"redirect_remote_open_remote")
        if hostData.remoteID and hostData.remoteID == sender then
            local px,py = hostData.window.getPosition()
            hostData.window.reposition(px,py,message.height,message.width)
            os.queueEvent("term_resize")
        end
    end
    
end
function host.open(hostData)
    rednet.send(hostData.remoteID,"redirect_remote_open_host")
end
function remote.listen_open(remoteData)
    while true do
        local res, sender, message = pcall(rednet.receive,"redirect_remote_open_remote")
        if remoteData.hostID and remoteData.hostID == sender then
            remote.open(remoteData)
        end
    end
    
end

function host.listen_resize(hostData)
    local run = true
    while run do
        local event,isFake = os.pullEventRaw("term_resize")
        if event == "terminate" and not isFake then -- I think this ends up handling the fact that the other two threads don't exit on terminate
            break
        end
        -- local px,py = hostData.window.getPosition()
        if not hostData.manualOffset then
            local ox, oy = getOffset(hostData.window)
            hostData.ox = ox
            hostData.oy = oy
        end
    end
end



function host.hook(remoteID,wind,ox,oy)
    local hostData = {isHost=true,remoteID = remoteID,window = wind.hostcopy, send_window = wind, ox = wind.ox, oy = wind.oy}
    if ox then
        hostData.ox = ox
        hostData.oy = oy
        hostData.manualOffset = true
    end
    parallel.waitForAny(
    function ()
        host.listen_events(hostData)
    end,function ()
        host.listen_open(hostData)
    end
    ,function ()
        host.listen_resize(hostData)
    end
    )
end



function remote.hook(hostID,wind)
    local ox, oy = getOffset(wind)
    local remoteData = {isHost=false,hostID = hostID,window = wind, ox = ox, oy = oy}
    remote.open(remoteData)
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
    nHeight = 20,
    names = {base = 13, ship = 14, phone = 12}
}