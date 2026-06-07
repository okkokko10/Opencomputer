local BaseElement = require "/okko.elements.BaseElement"
local helpblit = require "/okko.elements.helpblit"

---@class FillElement: BaseElement
---@field text string[][]
local FillElement = BaseElement:new()


function FillElement:onRender()
    -- local window = self:getWindow()
    helpblit.fill(1,1,self.width,self.height,function (x,y)
        return self:setCursorPos(x,y)
    end,self.text,self.col,self.back,self:setCursorPos(1,1))
end

function FillElement:create(text,col,back)
    return self:new({text=text,col=col,back=back})
end


return FillElement