
--- used the monitor code as baseline

local redirect_remote = require "redirect_remote"



-- todo: a program that modifies stuff about this.

local tArgs = { ... }


local remoteID = tonumber(tArgs[1])
if remoteID == nil then
    remoteID = redirect_remote.names[tArgs[1]]
end
local ox = tonumber(tArgs[2])
local oy = tonumber(tArgs[3])

local sProgram = tArgs[4]

local sPath = shell.resolveProgram(sProgram)
if sPath == nil then
    print("No such program: " .. sProgram)
    return
end



-- print(term.current())
local wind = redirect_remote.host.new_redirect(remoteID,term.current(),1,1,redirect_remote.nWidth,redirect_remote.nHeight)
local previousTerm = term.redirect(wind)

parallel.waitForAny((function()
        (shell.execute or shell.run)(sProgram, table.unpack(tArgs, 5))
    end),function () redirect_remote.host.hook(remoteID,wind,ox,oy) end)
term.redirect(previousTerm)