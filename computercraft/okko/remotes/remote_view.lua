
local redirect_remote = require "redirect_remote"

local sender = ...
local hostID = tonumber(sender)
if hostID == nil then
    hostID = redirect_remote.names[sender]
end


-- local wind = window.create(term.current(),1,1,redirect_remote.nWidth,redirect_remote.nHeight)
-- term.redirect(wind)
term.current().clear()
redirect_remote.remote.hook(hostID,term.current())