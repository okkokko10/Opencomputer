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
    local oval = original:get()
    -- local new = self:new({original=original,toMapped=toMapped,toOriginal=toOriginal}) -- these fields are not strictly necessary
    local new = self:new()
    ---@cast new BijectionVariable[T,To]
    if oval ~= nil then
        new.value = toMapped(oval)
    end
    BijectionVariable.makeBijection(new,original,toMapped,toOriginal)
    return new
    -- return self:new({value=nil, callbacks = original.callbacks})
end

function BijectionVariable.makeBijection(mapped,original,toMapped,toOriginal)
    

    original:addCallback(function (origins,v)
        mapped:set(toMapped(v:get()),origins)
    end)
    
    mapped:addCallback(function (origins,v)
        original:set(toOriginal(v:get()),origins)
    end)

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
