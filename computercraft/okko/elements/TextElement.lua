local BaseElement = require "/okko.elements.BaseElement"
local helpblit = require "/okko.elements.helpblit"
local Variable = require "/okko.Variables.Variable"

---@class TextElement: BaseElement
---@field text string[][]
local TextElement = BaseElement:new()


function TextElement:onRender()
    -- local window = self:getWindow()
    local text = Variable.getRealize(self.text)
    for index, value in ipairs(self.text) do
        value = Variable.getRealize(value)
        local window = self:setCursorPos(1,index)
        if type(value) == "string" then
            helpblit.blitHet(value, nil, nil, window)
        else
            helpblit.blitHet(Variable.getRealize(value[1]),Variable.getRealize(value[2]),Variable.getRealize(value[3]),window)
        end
    end

    
end

function TextElement:create(text)
    if type(text) == "string" then
        text = {text}
    end
    return self:new({text=text})
end


return TextElement