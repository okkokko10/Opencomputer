local Variable = require "/okko.Variables.Variable"
local debugger = require "/okko.integrated.debugger"



---@class NumberVariable: Variable
---@field range number
---@field offset number
local NumberVariable = Variable:new()


---@param range any
---@param value any
---@param offset any
---@return NumberVariable
function NumberVariable:createVisual(range,value,offset)
    offset = offset or 0
    return self:create(value+offset,1+offset,range+offset)
    -- return self:new({range=range or 1,value=value or 1, offset = offset or 0, callbacks = {}})
end
-- function NumberVariable:createInterval(min,max,value)
--     return self:create(max-min+1,value-min+1,min-1)
-- end
function NumberVariable:create(value,min,max)
    local new =  self:new({value = value, min = min, max = max, callbacks = {}})
    if min and max then
        new.range = max - min + 1
        new.offset = min-1
    end
    return new

end

function NumberVariable:setVisual(value,silent)
    self:set(value+self.offset,silent)
end
function NumberVariable:getVisual()
    return self:get()-self.offset
end

-- function NumberVariable:getRange()
--     return self.max - self.min + 1
-- end


function NumberVariable:getInterval()
    return self:get()
end

function NumberVariable:setInterval(value,silent)
    self:set(value,silent)
end


---@param slope? number
---@param offset? number
---@return RescaledVariable
function NumberVariable:rescale(slope,offset)
    require "/okko.Variables.RescaledVariable"
    return NumberVariable:rescale(slope,offset)
end
function NumberVariable:isValid()
    local value = self:get()
    if not value then
        return false
    end
    if (self.max and self.max < value) then
        return false
    end
    if (self.min and self.min > value) then
        return false
    end
    return true
end
function NumberVariable:enforceInterval()
    self:addCallback(function (origins,v)
        if not (v:isValid()) then
            debugger.log({"interval violation",origins=origins,v=v})
        end
    end)
    return self
end


return NumberVariable