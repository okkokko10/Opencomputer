
local NumberVariable = require "/okko.Variables.NumberVariable"


---@class RedstoneVariable: NumberVariable
local RedstoneVariable = NumberVariable:create(nil,0,15)


---@param value any
---@return RedstoneVariable
function RedstoneVariable:create(value)
    return self:new({value = value, callbacks = {}})
end

return RedstoneVariable