local Variable = require "/okko.Variables.Variable"
local RedstoneVariable = require "/okko.Variables.RedstoneVariable"

local RedstoneRelayOutVariable = {}


---comment
---@param relaySide RedstoneRelaySide
---@return RedstoneVariable
function RedstoneRelayOutVariable.convert(relaySide)
    local old_value = peripheral.call(relaySide.relay,"getAnalogOutput",relaySide.side)
    return RedstoneVariable:create(old_value):addCallback(function (v)
        peripheral.call(relaySide.relay,"setAnalogOutput",relaySide.side,v:getInterval())
    end)
end

local BuildVariable = require "/okko.Variables.BuildVariables"
BuildVariable.base_types.redstone_relay_out = RedstoneRelayOutVariable.convert

return RedstoneVariable