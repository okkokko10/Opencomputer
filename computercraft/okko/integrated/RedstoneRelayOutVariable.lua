local Variable = require "/okko.Variables.Variable"
local RedstoneVariable = require "/okko.Variables.RedstoneVariable"
local debugger         = require "/okko.integrated.debugger"

local RedstoneRelayOutVariable = {}


---comment
---@param relaySide RedstoneRelaySide
---@return RedstoneVariable
function RedstoneRelayOutVariable.convert(relaySide)
    local old_value = peripheral.call(relaySide.relay,"getAnalogOutput",relaySide.side)
    return RedstoneVariable:create(old_value):addCallback(function (origins,v)
        debugger.log({relay = relaySide, v = v, origins = origins})
        local val = v:get()
        if type(val) == "number" and 0 <= val and val <= 15 then
            peripheral.call(relaySide.relay,"setAnalogOutput",relaySide.side,val)
        end
    end)
end

local BuildVariable = require "/okko.Variables.BuildVariables"
BuildVariable.base_types.redstone_relay_out = RedstoneRelayOutVariable.convert

return RedstoneVariable