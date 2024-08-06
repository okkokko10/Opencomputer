--- represents a transform
--- ```
--- [xx xy xo] [x]   [x´]   [xx * x + xy * y + xo]
--- [yx yy yo] [y] = [y´] = [yx * x + yy * y + yo]
---            [1]
--- ```
---@class Transform2D
---@field xx number
---@field xy number
---@field xo number
---@field yx number
---@field yy number
---@field yo number
local Transform2D = {}

Transform2D.__index = Transform2D

---@class HasTransform
---@field transform Transform2D
---@field parent? HasTransform

function Transform2D:create(xx, xy, xo, yx, yy, yo)
    return setmetatable(
        {
            xx = xx,
            xy = xy,
            xo = xo,
            yx = yx,
            yy = yy,
            yo = yo
        },
        Transform2D
    )
end

function Transform2D:Move(x, y)
    return Transform2D:create(1, 0, 0, 1, x, y)
end

--- Move(1,1)
Transform2D.OneOne = Transform2D:Move(1, 1)

Transform2D.Identity = Transform2D:create(1, 0, 0, 1, 0, 0)

--- combines two transforms
--- ```
--- [xx xy xo] [xx xy xo]
--- [yx yy yo] [yx yy yo]
---            [ 0  0  1]
--- ```
--- @param other Transform2D
function Transform2D:mul(other)
    return Transform2D:create(
        self.xx * other.xx + self.xy * other.yx,
        self.xx * other.xy + self.xy * other.yy,
        self.xx * other.xo + self.xy * other.yo + self.xo,
        self.yx * other.xx + self.yy * other.yx,
        self.yx * other.xy + self.yy * other.yy,
        self.yx * other.xo + self.yy * other.yo + self.yo
    )
end

--- applies transform to position
--- @param x number
--- @param y number
--- @return number,number
function Transform2D:apply(x, y)
    return self.xx * x + self.xy * y + self.xo, self.yx * x + self.yy * y + self.yo
end

---applies transform to direction
---@param dx number
---@param dy number
---@return number
---@return number
function Transform2D:direction(dx, dy)
    return self.xx * x + self.xy * y, self.yx * x + self.yy * y
end

function Transform2D:invert(x, y)
    local c = x - self.xo
    local d = y - self.yo
    local det = (self.yy * self.xx - self.xy * self.yx)
    local out_x = (c * self.yy - d * self.xy) / det
    local out_y = (-c * self.yx + d * self.xx) / det
    return out_x, out_y
end

function Transform2D:determinant()
    return (self.yy * self.xx - self.xy * self.yx)
end

--- gets the inverse transform
function Transform2D:inverse()
    local det = self:determinant()
    return Transform2D:create(
        self.yy / det,
        -self.xy / det,
        (-self.xo * self.yy + self.yo * self.xy) / det,
        -self.yx / det,
        self.xx / det,
        (self.xo * self.yx - self.xx * self.yo) / det
    )
end

--- is this transform on the axis?
function Transform2D:isAxis()
    return true -- todo: dummy
end

Transform2D.posx = 4
Transform2D.negx = 5
Transform2D.posy = 1
Transform2D.negy = 0

function Transform2D:side()
    if self.xx > 0 then
        return Transform2D.posx
    elseif self.xx < 0 then
        return Transform2D.negx
    elseif self.yx > 0 then
        return Transform2D.posy
    elseif self.yx < 0 then
        return Transform2D.negy
    end
    return Transform2D.posx -- default
end

---returns whether a text box should be vertical or reversed
---@return boolean vertical
---@return boolean reverse
function Transform2D:vertical_reverse()
    if self.xx > 0 then
        return false, false
    elseif self.xx < 0 then
        return false, true
    elseif self.yx > 0 then
        return true, false
    elseif self.yx < 0 then
        return true, true
    end
    return false, false -- default
end

local function random()
    return 2 * math.random() - 1
end
local function roughly_equal(a, b, delta)
    return math.abs(a - b) < (delta or 0.01)
end

--- test
function Transform2D._test()
    local t
    repeat
        t = Transform2D:create(random(), random(), random(), random(), random(), random())
    until not roughly_equal(0, t:determinant())
    local x = random()
    local y = random()
    local inv = t:inverse()
    local iden = t:mul(inv)
    local x2, y2 = iden:apply(x, y)
    assert(roughly_equal(x, x2))
    assert(roughly_equal(y, y2))
    local x3, y3 = t:invert(x, y)
    local x4, y4 = inv:apply(x, y)
    assert(roughly_equal(x3, x4))
    assert(roughly_equal(y3, y4))
end

for i = 1, 10 do
    Transform2D._test()
end

return Transform2D
