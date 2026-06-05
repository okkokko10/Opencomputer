

---@class BaseElement
---@field children BaseElement[]
---@field parent BaseElement|nil
---@field px number
---@field py number
---@field width number
---@field height number
local BaseElement = {}
BaseElement.__index = BaseElement

---gets a window, and expands it if it's too small
---@param wish_width? number
---@param wish_height? number
function BaseElement:getWindow(wish_width,wish_height)
    if self.window then
        -- local w,h = self.window.getSize()
        if wish_height and (wish_width > self.width or wish_height > self.height) then
            self:remakeWindow(math.max(self.width,wish_width),math.max(self.height,wish_height))
        end
    else
        self:remakeWindow(wish_width or 1,wish_height or 1)
    end
    return self.window
end
function BaseElement:getPosition()
    return self.px,self.py
end
function BaseElement:setPosition(x,y)
    self.px = x
    self.py = y
    self:remakeWindow()
    self:update()
end
function BaseElement:getChildren()
    return self.children
end

function BaseElement:mouseEventRaw(event, misc, x, y)
    local px, py = self:getPosition()
    local x2 = x-px+1
    local y2 = y-py+1
    local w,h = self.window.getSize()
    if x2 < 1 or w < x2 or y2 < 1 or h < y2 then
        return false
    end
    if self:onMouseEvent(event,misc,x2,y2) then
        return true
    end
    for index, value in ipairs(self:getChildren()) do
        if (value:mouseEventRaw(event,misc,x2,y2)) then
            return true
        end
    end
    return false
end

--- abstract
function BaseElement:onMouseEvent(event, misc, x, y)
    return false
end

function BaseElement:getParentWindow(wish_width,wish_height)
    return self.parent:getWindow(wish_width,wish_height)
end

function BaseElement:remakeWindow(width,height)
    self.width = width or self.width
    self.height = height or self.height
    if self.window then
        self.window.reposition(self.px,self.py,self.width,self.height,self:getParentWindow(self.px+self.width-1,self.py+self.height-1))
    else
        self.window = window.create(self:getParentWindow(self.px+self.width-1,self.py+self.height-1),self.px,self.py,self.width,self.height)
    end
    return self.window
end

function BaseElement:onPostParentInit()
    
end

function BaseElement:addChild(child)
    self.children[#self.children+1] = child
    child.parent = self
    child:onPostParentInit()
end
-- function BaseElement:remove()
    
--     for index, value in ipairs(self:getChildren()) do 
--         value:remove()
--     end
-- end

function BaseElement:rec_redraw()
    for index, value in ipairs(self:getChildren()) do
        value:rec_redraw()
    end
    self:getWindow().redraw() -- should this be before or after?
end

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

BaseElement.px = 1
BaseElement.py = 1
BaseElement.width = 1
BaseElement.height = 1

function BaseElement:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if not o.children then o.children = {} end
    return o
    -- return setmetatable({children={},px=1,py=1},BaseElement)
end


return BaseElement