local GraphicsRect = require("graphics.GraphicsRect")
local Helper = require "Helper"
local ColorText = require "graphics.ColorText"

---@class Slider: GraphicsRect
---@field value integer
---@field private size integer
---@field pointer ColorTextPattern
---@field left_pattern ColorTextPattern
---@field right_pattern ColorTextPattern
---@field callbacks fun(value:integer,old_value:integer,size:integer?)[]
local Slider = setmetatable({}, GraphicsRect)

---comment
---@param transform Transform2D
---@param size integer
---@param pointer ColorTextPattern
---@param left_pattern ColorTextPattern
---@param right_pattern ColorTextPattern
---@vararg fun(callback_value:integer,old_value:integer,size:integer?) callback
function Slider:create(transform, size, pointer, left_pattern, right_pattern, ...)
    local slider = GraphicsRect.create(self, transform, size, 1)
    ---@cast slider Slider
    slider.size = size
    slider.value = 1
    slider.pointer = pointer
    slider.left_pattern = left_pattern
    slider.right_pattern = right_pattern
    slider.callbacks = {...}

    return slider
end

---@param x number
---@param y number
---@param button number
---@param playerName string
---@return boolean consumed
function Slider:onClick(x, y, button, playerName)
    local old_value = self.value
    self:SetValue(x)
    local new_value = self.value
    for _, callback in ipairs(self.callbacks) do
        callback(new_value, old_value, self.size)
    end
    return true
end
---registers a callback that takes a new value when it is set
---@param callback fun(value:integer,old_value:integer,size:integer?)
function Slider:registerCallback(callback)
    local index = #self.callbacks + 1
    self.callbacks[index] = callback
    return index
end
function Slider:forgetCallback(index)
    if self.callbacks[index] then
        self.callbacks[index] = nil
        return true
    end
    return false
end

function Slider:SetValue(value)
    self.value = value
    self:noteDirty()
end

---@param graphicsDraw GraphicsDraw
function Slider:draw(graphicsDraw)
    local arguments = {
        value = self.value,
        value_floor = math.floor(self.value),
        size = self.size,
        size_floor = math.floor(self.size),
        self = self
    }

    local left = ColorText.continuePattern(ColorText.format(self.left_pattern, arguments), 0, self.value)
    local right = ColorText.continuePattern(ColorText.format(self.right_pattern, arguments), self.value, self.size)
    local pointer = ColorText.moveAll(ColorText.format(self.pointer, arguments), self.value, 0)

    graphicsDraw:drawColorText(left)
    graphicsDraw:drawColorText(right)
    graphicsDraw:drawColorText(pointer)
end

return Slider
