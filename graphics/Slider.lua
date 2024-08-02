local GraphicsRect = require("graphics.GraphicsRect")
local Helper = require "Helper"

---@class Slider: GraphicsRect
---@field value integer
---@field private size integer
---@field private vertical boolean
local Slider = setmetatable({}, GraphicsRect)

---comment
---@param x integer
---@param y integer
---@param size integer
---@param vertical? boolean
function Slider:create(x, y, size, vertical)
    local w = 1
    local h = 1
    if vertical then
        h = size
    else
        w = size
    end
    local gRect = GraphicsRect.create(self, x, y, w, h)
    ---@cast gRect Slider
    gRect.size = size
    gRect.value = 1
    gRect.vertical = vertical or false
    return gRect
end

--- overload this. return if the click is consumed.
---@param x number
---@param y number
---@param button number
---@param playerName string
---@return boolean consumed
function Slider:onClick(x, y, button, playerName)
    local value = self.vertical and y or x
    self.value = value
    self:noteDirty()
    return true
end

---@param graphicsDraw GraphicsDraw
function Slider:draw(graphicsDraw)
    --- todo: limit color changes to 3 by drawing in a different order
    local function sizeColor(i)
        if i % 2 == 0 then
            return 0x444444
        else
            return 0x999999
        end
    end
    local function valueColor(i)
        if i % 2 == 0 then
            return 0x449944
        else
            return 0x994499
        end
    end
    local pointColor = 0xFF8000

    local dx = self.vertical and 0 or 1
    local dy = self.vertical and 1 or 0

    local value_split = Helper.splitNumber(self.value, 10)
    -- Helper.splitNumber(self.size - self.value, 10, 10 - self.value % 10)
    local size_offset = (#value_split - 1) * 10
    local size_split = Helper.splitNumber(self.size - size_offset, 10)
    local total = size_offset -- the greater part is drawn first, so it can be drawn over
    for index, value in ipairs(size_split) do
        graphicsDraw:set(
            dx * total,
            dy * total,
            string.rep("¤", value),
            nil,
            sizeColor(index + #value_split),
            self.vertical
        )
        total = total + value
    end
    total = 0
    for index, value in ipairs(value_split) do
        graphicsDraw:set(dx * total, dy * total, string.rep("¤", value), nil, valueColor(index), self.vertical)
        total = total + value
    end

    graphicsDraw:set(dx * self.value, dy * self.value, tostring(self.value % 10), nil, pointColor, self.vertical)
end

return Slider
