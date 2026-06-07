local Variable = require "/okko.Variables.Variable"


---@generic T, To
---@class BijectionVariable: Variable[T]
local BijectionVariable = Variable:new()


--- watch out for the order in which things change

---@generic T, To
---@param original Variable[To]
---@param toMapped fun(value:To):T
---@param toOriginal fun(value:T):To
---@return BijectionVariable[T,To]
function BijectionVariable:create(original,toMapped,toOriginal)
    -- local new = self:new({original=original,toMapped=toMapped,toOriginal=toOriginal}) -- these fields are not strictly necessary
    local new = self:new()
    ---@cast new BijectionVariable[T,To]
    local oval = original:get()
    if oval ~= nil and toMapped then
        new.value = toMapped(oval)
    end
    BijectionVariable.makeBijection(new,original,toMapped,toOriginal)
    return new
    -- return self:new({value=nil, callbacks = original.callbacks})
end


-- returns functions that update the values immediately
function BijectionVariable.makeBijection(mapped,original,toMapped,toOriginal)
    local function updateMapped (origins)
        mapped:set(toMapped(original:get()),origins)
    end
    if toMapped then
        original:addCallback(updateMapped)
    end
    local function updateOriginal (origins)
        original:set(toOriginal(mapped:get()),origins)
    end
    if toOriginal then
        mapped:addCallback(updateOriginal)
    end
    
    return function ()
        if toMapped then
            updateMapped({original=1,n=1})
        end
    end,function ()
        if toOriginal then
            updateOriginal({mapped=1,n=1})
        end
    end
end



---@generic T, To
---@param self Variable[To]
---@param toMapped fun(value:To):T
---@param toOriginal fun(value:T):To
---@return BijectionVariable[T,To]
function Variable:bijection(toMapped,toOriginal)
    return BijectionVariable:create(self,toMapped,toOriginal)
end

return BijectionVariable
