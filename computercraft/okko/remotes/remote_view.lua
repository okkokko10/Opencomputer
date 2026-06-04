
local redirect_remote = require "redirect_remote"

local sender = ...
local hostID = tonumber(sender)


local wind = window.create(term.current(),1,1,redirect_remote.nWidth,redirect_remote.nHeight)
term.redirect(wind)
redirect_remote.remote.hook(hostID,wind)