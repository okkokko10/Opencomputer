local Variable = require "/okko.Variables.Variable"

local RedstoneVariable = {}


---comment
---@param relaySide RedstoneRelaySide
---@return Variable
function RedstoneVariable.convert(relaySide)
    local old_value = peripheral.call(relaySide.relay,"getAnalogOutput",relaySide.side)
    return Variable:createInterval(0,15,old_value):addCallback(function (v)
        peripheral.call(relaySide.relay,"setAnalogOutput",relaySide.side,v:getInterval())
    end)
end

local BuildVariable = require "/okko.Variables.BuildVariable"
BuildVariable.base_types.redstone_relay_out = RedstoneVariable.convert

return RedstoneVariable