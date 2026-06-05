local BaseElement = require "BaseElement"

---@class BaseVariableRectElement: BaseElement
---@field vx? Variable
---@field vy? Variable
local BaseVariableRectElement = BaseElement:new()

function BaseVariableRectElement:onMouseEvent(event, misc, x, y)
    -- if event ~= ""
    if self.vx then
        self.vx:set(x)
    end
    if self.vy then
        self.vy:set(y)
    end
    -- self:update()
    return true
end

function BaseVariableRectElement:onPostParentInit()
    self:remakeWindow(self.vx and self.vx.range or 1, self.vy and self.vy.range or 1)
end


function BaseVariableRectElement:getVariables()
    return self.vx,self.vy
    
end


function BaseVariableRectElement:create(vx,vy)
    return self:new({vx=vx,vy=vy})
end
return BaseVariableRectElement