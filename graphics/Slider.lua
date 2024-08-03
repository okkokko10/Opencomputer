local GraphicsRect = require("graphics.GraphicsRect")
local Helper = require "Helper"

---@class Slider: GraphicsRect
---@field value integer
---@field private size integer
---@field private vertical boolean
---@field pointer string|nil
---@field checker_interval? integer
---@field fillchar? string
---@field point_fore? integer
---@field point_back? integer
---@field left_fore_A? integer
---@field left_back_A? integer
---@field left_fore_B? integer
---@field left_back_B? integer
---@field right_fore_A? integer
---@field right_back_A? integer
---@field right_fore_B? integer
---@field right_back_B? integer
local Slider =
    setmetatable(
    {
        checker_interval = 8,
        fillchar = ":",
        vertical = false,
        point_fore = 0xFFFFFF,
        point_back = 0xFF8000,
        left_fore_A = 0xFFFFFF,
        left_back_A = 0x444444,
        left_fore_B = 0xFFFFFF,
        left_back_B = 0x999999,
        right_fore_A = 0xFFFFFF,
        right_back_A = 0x449944,
        right_fore_B = 0xFFFFFF,
        right_back_B = 0x994499
    },
    GraphicsRect
)

---comment
---@param x integer
---@param y integer
---@param size integer
---@param checker_interval? integer
---@param vertical? boolean
---@param pointer? string|nil -- leave nil to use the current value. right justified
---@param point_fore? integer
---@param point_back? integer
---@param fillchar? string
---@param left_fore_A? integer
---@param left_back_A? integer
---@param left_fore_B? integer
---@param left_back_B? integer
---@param right_fore_A? integer
---@param right_back_A? integer
---@param right_fore_B? integer
---@param right_back_B? integer
function Slider:create(
    x,
    y,
    size,
    checker_interval,
    vertical,
    pointer,
    point_fore,
    point_back,
    fillchar,
    left_fore_A,
    left_back_A,
    left_fore_B,
    left_back_B,
    right_fore_A,
    right_back_A,
    right_fore_B,
    right_back_B)
    local w = 1
    local h = 1
    if vertical then
        h = size
    else
        w = size
    end
    local gRect = GraphicsRect.create(self, x, y, w, h)
    ---@cast gRect Slider
    gRect.pointer = pointer
    gRect.size = size
    gRect.value = 1
    gRect.vertical = vertical or false
    gRect.checker_interval = checker_interval
    gRect.fillchar = fillchar
    gRect.point_fore = point_fore
    gRect.point_back = point_back
    gRect.left_fore_A = left_fore_A
    gRect.left_back_A = left_back_A
    gRect.left_fore_B = left_fore_B
    gRect.left_back_B = left_back_B
    gRect.right_fore_A = right_fore_A
    gRect.right_back_A = right_back_A
    gRect.right_fore_B = right_fore_B
    gRect.right_back_B = right_back_B

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

    local dx = self.vertical and 0 or 1
    local dy = self.vertical and 1 or 0
    -- todo: GraphicsRect.vertical, which can automatically flip a GraphicsDraw's x and y

    local value_split = Helper.splitNumber(self.value, self.checker_interval)
    -- Helper.splitNumber(self.size - self.value, 10, 10 - self.value % 10)
    local number_offset = math.max(#value_split - 1, 0)
    local size_offset = number_offset * self.checker_interval
    local size_split = Helper.splitNumber(self.size - size_offset, self.checker_interval)
    local total = size_offset -- the greater part is drawn first, so it can be drawn over
    for index, value in ipairs(size_split) do
        local fore, back = rightColor(index + number_offset)
        graphicsDraw:set(dx * total, dy * total, string.rep(self.fillchar, value), fore, back, self.vertical)
        total = total + value
    end
    total = 0
    for index, value in ipairs(value_split) do
        local fore, back = leftColor(index)
        graphicsDraw:set(dx * total, dy * total, string.rep(self.fillchar, value), fore, back, self.vertical)
        total = total + value
    end
    local text = self.pointer or tostring(self.value)
    total = self.value - #text + 1 -- right justified - makes sure the string isn't outside borders.
    graphicsDraw:set(dx * total, dy * total, text, self.point_fore, self.point_back, self.vertical)
    graphicsDraw:setBackground(old_color)
end

return Slider
