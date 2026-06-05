

---@class BaseElement
---@field children BaseElement[]
---@field parent BaseElement|nil
---@field px number
---@field py number
---@field width number
---@field height number
---@field ax number
---@field ay number
---@field awindow unknown
local BaseElement = {}
BaseElement.__index = BaseElement

-- ---gets a window, and expands it if it's too small
-- ---@param wish_width? number
-- ---@param wish_height? number
-- function BaseElement:getWindow(wish_width,wish_height)
--     if self.window then
--         -- local w,h = self.window.getSize()
--         if wish_height and (wish_width > self.width or wish_height > self.height) then
--             self:remakeWindow(math.max(self.width,wish_width),math.max(self.height,wish_height))
--         end
--     else
--         self:remakeWindow(wish_width or 1,wish_height or 1)
--     end
--     return self.window
-- end

function BaseElement:getPosition()
    return self.px,self.py
end



function BaseElement:setPosition(x,y)
    self.px = x
    self.py = y
    -- self:remakeWindow()
    self:update()
    return self
end

function BaseElement:setSize(hx,hy)
    self.width = hx
    self.height = hy
    self:update()
    return self
    
end
function BaseElement:getSize()
    return self.width,self.height
    
end


function BaseElement:getParentGlobalPosition()
    if self.parent then
        return self.parent:getPosition()
    else
        return 1, 1
    end
end
function BaseElement:getGlobalPosition()
    local plx, ply = self:getParentGlobalPosition()
    return plx+self.px-1,ply+self.py-1
end


function BaseElement:getChildren()
    return self.children
end

function BaseElement:toGlobalPosition(x,y)
    local gx,gy = self:getGlobalPosition()
    return gx + x - 1, gy + y - 1
end

function BaseElement:toLocalPosition(x,y)
    local gx,gy = self:getGlobalPosition()
    return x - (gx - 1), y - (gy - 1)
end


-- sets cursor pos to where it would be, and returns the window to be written to
function BaseElement:setCursorPos(x,y)
    self.awindow.setCursorPos(self:toGlobalPosition(x,y))
    return self.awindow
end

function BaseElement:isLocalBounded(x,y)
    return (1 <= x and x <= self.width and 1 <= y and y <= self.height) 
end

local consumeEvents = false
function BaseElement:mouseEventRaw(event, misc, x, y)
    -- local px, py = self:getPosition()
    -- local x2 = x-px+1
    -- local y2 = y-py+1
    -- 
    if self:onMouseEvent(event,misc,x,y) and consumeEvents then
        return true
    end
    for index, value in ipairs(self:getChildren()) do
        if (value:mouseEventRaw(event,misc,x,y)) and consumeEvents then
            return true
        end
    end
    return false
end

--- abstract
function BaseElement:onMouseEvent(event, misc, x, y)
    return false
end

-- function BaseElement:getParentWindow(wish_width,wish_height)
--     return self.parent:getWindow(wish_width,wish_height)
-- end

-- function BaseElement:remakeWindow(width,height)
--     self.width = width or self.width
--     self.height = height or self.height
--     if self.window then
--         self.window.reposition(self.px,self.py,self.width,self.height,self:getParentWindow(self.px+self.width-1,self.py+self.height-1))
--     else
--         self.window = window.create(self:getParentWindow(self.px+self.width-1,self.py+self.height-1),self.px,self.py,self.width,self.height)
--     end
--     return self.window
-- end

function BaseElement:onPostParentInit()
    
end

function BaseElement:onPostAddChild(child)
    
end
function BaseElement:updateChildWindow(awindow)
    self.awindow = awindow
    for index, value in ipairs(self:getChildren()) do
        value:updateChildWindow(awindow)
    end
end

function BaseElement:addChild(child)
    self.children[#self.children+1] = child
    child.parent = self
    child.awindow = self.awindow
    child:onPostParentInit()
    self:onPostAddChild(child)
    return self
end
-- function BaseElement:remove()
    
--     for index, value in ipairs(self:getChildren()) do 
--         value:remove()
--     end
-- end

-- function BaseElement:rec_redraw()
--     for index, value in ipairs(self:getChildren()) do
--         value:rec_redraw()
--     end
--     self:getWindow().redraw() -- should this be before or after?
-- end

function BaseElement:onUpdate()
    
end
function BaseElement:update()
    
end

function BaseElement:onRender()
    
end

function BaseElement:rec_render()
    self:onRender() -- should this be before or after?
    for index, value in ipairs(self:getChildren()) do
        value:rec_render()
    end
end

-- utility
function BaseElement:defineCenter(x,y)
    self.cx = x
    self.cy = y
    return self
end
function BaseElement:setCenter(x,y)
    self.px = x - self.cx + 1
    self.py = y - self.cy + 1
    return self
end



BaseElement.px = 1
BaseElement.py = 1
BaseElement.width = 1
BaseElement.height = 1
BaseElement.cx = 1 --- center, for "setCenter"
BaseElement.cy = 1

function BaseElement:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if not o.children then o.children = {} end
    return o
    -- return setmetatable({children={},px=1,py=1},BaseElement)
end


return BaseElement