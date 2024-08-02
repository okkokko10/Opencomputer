local component = require "component"

---@class GraphicsDraw: Rect
---@field buffer integer
local GraphicsDraw = {}

GraphicsDraw.__index = GraphicsDraw

GraphicsDraw.gpu_data = {
    gpu = component.gpu,
    background = -1,
    foreground = -1,
    activeBuffer = 0
}
GraphicsDraw.gpu = GraphicsDraw.gpu_data.gpu

function GraphicsDraw:create(x, y, w, h, buffer)
    return setmetatable(
        {
            x = x or self.x or 1,
            y = y or self.y or 1,
            w = w or self.w,
            h = h or self.h,
            buffer = buffer or self.buffer or 0
        },
        GraphicsDraw
    )
end

---gets a GraphicsDraw interface that is relative to the rect
---@param rect Rect
---@return GraphicsDraw
function GraphicsDraw:inside(rect)
    return self:create(self.x + rect.x, self.y + rect.y, rect.w, rect.h, self.buffer)
end

---executes func in another buffer, then uses bitblt to render it all at once.
---buffer must be an active buffer index
---@generic T...
---@param buffer integer
---@param func fun(gDraw:GraphicsDraw,...:T...)
---@param ... T...
function GraphicsDraw:inBuffer(buffer, func, ...)
    local temp = self:create(1, 1, self.w, self.h, buffer)
    func(temp, ...)
    self:bitbltFrom(temp)
end

---comment
---@param other GraphicsDraw
function GraphicsDraw:bitbltFrom(other)
    self.gpu_data.gpu.bitblt(
        self.buffer,
        self.x,
        self.y,
        math.min(self.w, other.w),
        math.min(self.h, other.h),
        other.buffer,
        other.x,
        other.y
    )
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

---comment
---@param x number
---@param y number
---@param value string
---@param foreground? integer
---@param background? integer
---@param vertical? boolean
function GraphicsDraw:set(x, y, value, foreground, background, vertical)
    -- todo: what if y or x are negative?
    if y > self.h or x > self.w then
        return false
    end
    local maxLength = vertical and (self.h - y) or (self.w - x)
    if #value > maxLength then
        value = string.sub(value, 1, maxLength)
    end
    self:enter()
    self:setForeground(foreground)
    self:setBackground(background)
    return self.gpu_data.gpu.set(self.x + x, self.y + y, value, vertical) -- todo: 0-indexed
end

---comment
---@param char string
---@param foreground? integer
---@param background? integer
---@param x? integer
---@param y? integer
---@param w? integer
---@param h? integer
---@return boolean
function GraphicsDraw:fill(char, foreground, background, x, y, w, h)
    self:enter()
    self:setForeground(foreground)
    self:setBackground(background)
    x = x or 0
    y = y or 0
    w = w or self.w
    h = h or self.h
    -- assert(#char == 1)
    local x1 = self.x + x
    local y1 = self.y + y
    local w1 = math.min(w, self.w - x)
    local h1 = math.min(h, self.h - y)
    if w1 <= 0 or h1 <= 0 then
        return false
    end
    return self.gpu_data.gpu.fill(x1, y1, w1, h1, char)
end

return GraphicsDraw
