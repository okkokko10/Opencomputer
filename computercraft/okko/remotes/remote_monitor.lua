
--- used the monitor code as baseline

local redirect_remote = require "redirect_remote"



-- todo: a program that modifies stuff about this.

local tArgs = { ... }

local sProgram = tArgs[2]

local sPath = shell.resolveProgram(sProgram)
if sPath == nil then
    print("No such program: " .. sProgram)
    return
end

local remoteID = tonumber(tArgs[1])

-- print(term.current())
local wind = redirect_remote.host.new_redirect(remoteID,term.current(),1,1,redirect_remote.nWidth,redirect_remote.nHeight)
local previousTerm = term.redirect(wind)

parallel.waitForAny((function()
        (shell.execute or shell.run)(sProgram, table.unpack(tArgs, 3))
    end),function () redirect_remote.host.listen_events(remoteID,wind) end)
term.redirect(previousTerm)