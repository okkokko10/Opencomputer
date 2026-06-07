local Variable = require "/okko.Variables.Variable"
local BijectionVariable = require "/okko.Variables.BijectionVariable"

local NumberVariable = require "/okko.Variables.NumberVariable"


---@class RescaledVariable: NumberVariable
local RescaledVariable = NumberVariable:new()


--- watch out for the order in which things change

---@param original NumberVariable
---@param slope? number
---@param offset? number
---@return RescaledVariable
function RescaledVariable:create(original,slope,offset)
    slope = slope or 1
    offset = offset or 0
    local function toMapped(x)
        return x and slope*x + offset
    end
    local function toOriginal(y)
        return y and (y-offset)/slope
    end

    local oval = original:get()
    local nmin = original.min and toMapped(original.min)
    local nmax = original.max and toMapped(original.max)
    if slope < 0 then
        nmin,nmax = nmax,nmin
    end
    local new = NumberVariable:create(oval and toMapped(oval),nmin,nmax)
    BijectionVariable.makeBijection(new,original,toMapped,toOriginal)()
    return new
    -- return self:new({value=nil, callbacks = original.callbacks})
end
---@param slope? number
---@param offset? number
---@return RescaledVariable
function NumberVariable:rescale(slope,offset)
    return RescaledVariable:create(self,slope,offset)
end

return RescaledVariable