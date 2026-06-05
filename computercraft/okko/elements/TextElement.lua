local BaseElement = require "okko.elements.BaseElement"
local helpblit = require "okko.elements.helpblit"

---@class TextElement: BaseElement
---@field text string[][]
local TextElement = BaseElement:new()


function TextElement:onRender()
    -- local window = self:getWindow()
    for index, value in ipairs(self.text) do
        local window = self:setCursorPos(1,index)
        if type(value) == "string" then
            helpblit.blitHet(value, nil, nil, window)
        else
            helpblit.blitHet(value[1],value[2],value[3],window)
        end
    end

    
end

function TextElement:create(text)
    return self:new({text=text})
end


return TextElement