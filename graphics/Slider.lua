local GraphicsRect = require("graphics.GraphicsRect")
local Helper = require "Helper"
local ColorText = require "graphics.ColorText"

---@class Slider: GraphicsRect
---@field value integer
---@field private size integer
---@field pointer ColorTextPattern
---@field left_pattern ColorTextPattern
---@field right_pattern ColorTextPattern
local Slider = setmetatable({}, GraphicsRect)

---comment
---@param transform Transform2D
---@param size integer
---@param pointer ColorTextPattern
---@param left_pattern ColorTextPattern
---@param right_pattern ColorTextPattern
function Slider:create(transform, size, pointer, left_pattern, right_pattern)
    local slider = GraphicsRect.create(self, transform, size, 1)
    ---@cast slider Slider
    slider.size = size
    slider.value = 1
    slider.pointer = pointer
    slider.left_pattern = left_pattern
    slider.right_pattern = right_pattern

    return slider
end

--- overload this. return if the click is consumed.
---@param x number
---@param y number
---@param button number
---@param playerName string
---@return boolean consumed
function Slider:onClick(x, y, button, playerName)
    self.value = x
    self:noteDirty()
    return true
end

---@param graphicsDraw GraphicsDraw
function Slider:draw(graphicsDraw)
    local old_color = graphicsDraw.gpu_data.gpu.getBackground()
    --- todo: limit color changes to 3 by drawing in a different order
    local function rightColor(i)
        if i % 2 == 1 then
            return self.left_fore_A, self.left_back_A
        else
            return self.left_fore_B, self.left_back_B
        end
    end
    local function leftColor(i)
        if i % 2 == 1 then
            return self.right_fore_A, self.right_back_A
        else
            return self.right_fore_B, self.right_back_B
        end
    end

    local arguments = {value = self.value, size = self.size}

    local left = ColorText.continuePattern(ColorText.format(self.left_pattern, arguments), 0, self.value)
    local right = ColorText.continuePattern(ColorText.format(self.right_pattern, arguments), self.value, self.size)
    local pointer = ColorText.moveAll(ColorText.format(self.pointer, arguments), self.value, 0)

    graphicsDraw:drawColorTextStrip(left)
    graphicsDraw:drawColorTextStrip(right)
    graphicsDraw:drawColorTextStrip(pointer)
end

return Slider
