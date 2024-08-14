local component = require "component"
local Transform2D = require "graphics.Transform2D"
local ColorText = require "graphics.ColorText"

---@class GraphicsDraw: TRect
---@field buffer integer
local GraphicsDraw = {}

GraphicsDraw.__index = GraphicsDraw

GraphicsDraw.gpu_data = {
    gpu = component.gpu,
    background = -1,
    foreground = -1,
    activeBuffer = 0
}

function GraphicsDraw:create(transform, w, h, buffer)
    return setmetatable(
        {
            transform = transform,
            w = w or self.w,
            h = h or self.h,
            buffer = buffer or self.buffer or 0
        },
        GraphicsDraw
    )
end

---gets a GraphicsDraw interface that is relative to the rect
---@param rect TRect
---@return GraphicsDraw
function GraphicsDraw:inside(rect)
    self.__index = self
    return setmetatable({w = rect.w, h = rect.h, transform = self.transform:mul(rect.transform)}, self)
end

---executes func in another buffer, then uses bitblt to render it all at once.
---buffer must be an active buffer index
---@generic T...
---@param buffer integer
---@param func fun(gDraw:GraphicsDraw,...:T...)
---@param ... T...
function GraphicsDraw:inBuffer(buffer, func, ...)
    local temp = self:create(Transform2D.OneOne, self.w, self.h, buffer)
    func(temp, ...)
    self:bitbltFrom(temp)
end

--- gets a proper rect, not a TRect
--- a rotated rect with 1 width and height is shifted, because rotation is around the corner
--- @param self TRect
function GraphicsDraw:getBounds()
    local xmax = -math.huge
    local ymax = -math.huge
    local xmin = math.huge
    local ymin = math.huge
    for _, v in ipairs({{0, 0}, {0, self.h}, {self.w, self.h}, {self.w, 0}}) do
        local ex, ey = self.transform:apply(table.unpack(v))
        xmax = math.max(ex, xmax)
        ymax = math.max(ey, ymax)
        xmin = math.min(ex, xmin)
        ymin = math.min(ey, ymin)
    end

    return {x = xmin, y = ymin, w = xmax - xmin, h = ymax - ymin}
end

---comment
---@param other GraphicsDraw
function GraphicsDraw:bitbltFrom(other)
    local s = self:getBounds()
    local o = other:getBounds()
    self.gpu_data.gpu.bitblt(self.buffer, s.x, s.y, math.min(s.w, o.w), math.min(s.h, o.h), other.buffer, o.x, o.y)
end

function GraphicsDraw:setBackground(color)
    if not color then
        return
    end
    self:enter()
    if self.gpu_data.background ~= color then -- see if it's necessary
        self.gpu_data.background = color
        return self.gpu_data.gpu.setBackground(color)
    else
        return color
    end
end

function GraphicsDraw:setForeground(color)
    if not color then
        return
    end
    self:enter()
    if self.gpu_data.foreground ~= color then -- see if it's necessary
        self.gpu_data.foreground = color
        return self.gpu_data.gpu.setForeground(color)
    else
        return color
    end
end

---sets gpu's buffer to this one
function GraphicsDraw:enter()
    if self.gpu_data.activeBuffer ~= self.buffer then
        self.gpu_data.activeBuffer = self.buffer
        self.gpu_data.gpu.setActiveBuffer(self.buffer)
        self.gpu_data.background = self.gpu_data.gpu.getBackground()
        self.gpu_data.foreground = self.gpu_data.gpu.getForeground()
    end
end

function GraphicsDraw:setColors(foreground, background)
    self:enter()
    self:setForeground(foreground)
    self:setBackground(background)
end

--- sets text at position, without rotating it.
---@param x number
---@param y number
---@param value string
---@param foreground? integer
---@param background? integer
---@param vertical? boolean
function GraphicsDraw:setText(x, y, value, foreground, background, vertical)
    -- todo: what if y or x are negative?
    if false then -- limit the positions
        if y > self.h or x > self.w then
            return false
        end
        local maxLength = vertical and (self.h - y) or (self.w - x)
        if #value > maxLength then
            value = string.sub(value, 1, maxLength) --+ string.rep("x", #value - maxLength)
        end
    end
    self:setColors(foreground, background)
    local x1, y1 = self.transform:apply(x, y)
    return self.gpu_data.gpu.set(x1, y1, value, vertical) -- todo: 0-indexed
end

function GraphicsDraw:line(x1, y1, x2, y2, pattern)
end

-- function GraphicsDraw:set(value, foreground, background)
-- self:setColors(foreground, background)

--     if self.transform:isAxis() then
--         self.gpu_data.gpu.set()
--     end
-- end

---fills the whole bounds
---@param char string
---@param foreground? integer
---@param background? integer
---@return boolean
function GraphicsDraw:fill(char, foreground, background)
    self:setColors(foreground, background)

    if self.transform:isAxis() then
        local rect = self:getBounds()
        return self.gpu_data.gpu.fill(rect.x, rect.y, rect.w, rect.h, char)
    end
    --- todo: other ways
    return false
end

---draws a single ColorText
---@param strip ColorTextStrip
function GraphicsDraw:drawColorTextStrip(strip)
    -- self:setColors(colorText.fg, colorText.bg)
    local vertical, reverse = self.transform:vertical_reverse()
    if strip.anchor then
        vertical, reverse = false, false
    end
    if reverse then
        strip = ColorText.reverse(strip)
    end
    self:setColors(strip.fg, strip.bg)
    local x1, y1
    if strip.anchor then
        local ax, ay = table.unpack(strip.anchor)
        x1, y1 = self.transform:apply(ax, ay)
        x1 = x1 + strip.column - ax
        y1 = y1 - strip.row - ay
    else
        x1, y1 = self.transform:apply(strip.column, strip.row)
    end
    return self.gpu_data.gpu.set(x1, y1, strip.text, vertical)
end

---comment
---@param texts ColorTextStrip[]
function GraphicsDraw:drawColorText(texts)
    for index, value in ipairs(texts) do
        self:drawColorTextStrip(value)
    end
end

---writes to output, string but brackets are highlighted
---@param text string
---@param colors? table
---@param start? integer -- which index of colors to start at
---@param background_mult? number
function GraphicsDraw.printBrackets(text, colors, start, background_mult)
    colors = colors or {0xFF0000, 0x00FF00, 0x0000FF, 0x00FFFF, 0xFF00FF, 0xFFFF00}
    assert(colors[1], "there must be colors")
    local term = require("term")
    local originalForeground = term.gpu().getForeground()
    local originalBackground = term.gpu().getBackground()
    local color_index_size = #colors
    local opening = "%[%(%{"
    local closing = "%]%)%}"
    local brackets = "()([" .. opening .. closing .. "])()"
    background_mult = background_mult or 0.5

    local function darken(color, mult)
        local out = 0
        for i = 0, 24, 8 do
            out = out | (math.min(math.floor((color & (0xFF << i)) * mult), (0xFF << i)) & (0xFF << i))
        end
        return out
    end

    local function setBackground(ind)
        term.gpu().setBackground(darken(colors[ind + 1], background_mult))
    end
    local function setForeground(ind)
        term.gpu().setForeground(colors[ind + 1])
    end
    local function baseForeground()
        term.gpu().setForeground(originalForeground)
    end
    local function baseBackground()
        term.gpu().setBackground(originalBackground)
    end

    local color_index = (start or 1) - 1

    ---update color
    ---nil argument means set the background color
    ---@param bracket string|nil
    local function updateColor(bracket)
        if bracket then
            if string.match(bracket, "[" .. opening .. "]") then
                setBackground(color_index)
                color_index = (color_index + 1) % color_index_size
                setForeground(color_index)
            else
                setForeground(color_index)
                color_index = (color_index - 1) % color_index_size
                setBackground(color_index)
            end
        else
            setBackground(color_index)
            baseForeground()
        end
    end

    local i = 1
    while i <= #text do
        local bracket_index, bracket, next_index = string.match(text, brackets, i)
        if not bracket_index then
            bracket_index = #text + 1
            next_index = #text + 2
        end
        updateColor()
        term.write(string.sub(text, i, bracket_index - 1))
        if bracket then
            updateColor(bracket)
            term.write(bracket)
        end
        i = next_index
    end
    baseBackground()
    baseForeground()
end

return GraphicsDraw
