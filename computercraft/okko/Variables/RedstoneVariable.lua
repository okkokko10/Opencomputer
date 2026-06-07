
local NumberVariable = require "/okko.Variables.NumberVariable"


---@class RedstoneVariable: NumberVariable
local RedstoneVariable = NumberVariable:new()



---@param value any
---@return RedstoneVariable
function RedstoneVariable:create(value)
    return self:new(NumberVariable:createInterval(0,15,value))
end

return RedstoneVariable