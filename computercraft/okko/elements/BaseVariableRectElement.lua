local BaseElement = require "/okko.elements.BaseElement"

---@class BaseVariableRectElement: BaseElement
---@field vx? Variable
---@field vy? Variable
local BaseVariableRectElement = BaseElement:new()

function BaseVariableRectElement:onMouseEvent(event, misc, x, y)
    
    local x2, y2 = self:toLocalPosition(x,y)
    -- if event ~= ""
    -- print(x,y)
    if not self:isLocalBounded(x2,y2) then
        return false
    end
    if self.vx then
        self.vx:setVisual(x2)
    end
    if self.vy then
        self.vy:setVisual(y2)
    end
    -- self:update()
    return true
end

function BaseVariableRectElement:onPostParentInit()
    self.width = self.vx and self.vx.range or 1
    self.height = self.vy and self.vy.range or 1
    return self
    -- self:remakeWindow(self.vx and self.vx.range or 1, self.vy and self.vy.range or 1)
end


function BaseVariableRectElement:getVariables()
    return self.vx,self.vy
    
end


function BaseVariableRectElement:create(vx,vy)
    return self:new({vx=vx,vy=vy}):onPostParentInit()
end
return BaseVariableRectElement