local Variable = require "/okko/elements/Variable"

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

-- --- coll is a nested table with RedstoneRelaySide at the leaves, or a RedstoneRelaySide
-- --- coll cannot contain "relay" unless it is a leaf
-- function RedstoneVariable.convertNested(coll)
--     if coll.relay then
--         return RedstoneVariable.convert(coll)
--     end
--     local out = {}
--     for key, value in pairs(coll) do
--         if type(value) == "table" then
--             out[key] = RedstoneVariable.convertNested(value)
--         else
--             out[key] = value
--         end
--     end
--     return out
-- end

return RedstoneVariable