---@class Rect
---@field x number
---@field y number
---@field w number
---@field h number -- <y+h is the exclusive edge. when h=1, the rect is 1 row high

---@class GraphicsRect: Rect
---@field children GraphicsRect[]
---@field parent? GraphicsRect
---@field parent_index? integer
---@field dirty boolean
---@field children_dirty_any boolean
---@field children_dirty table<integer,boolean> -- children_dirty[i]==true means that child is dirty
local GraphicsRect = {}

GraphicsRect.__index = GraphicsRect

function GraphicsRect:create(x, y, w, h, children)
    self.__index = self
    local gRect =
        setmetatable(
        {
            x = x,
            y = y,
            w = w,
            h = h,
            children = children or {},
            parent = nil,
            parent_index = nil,
            dirty = true,
            children_dirty_any = false,
            children_dirty = {}
        },
        self
    )
    for index, child in pairs(gRect.children) do
        child.parent = gRect
        child.parent_index = index
    end
    return gRect
end

---notes the parent that this is dirty.
---@param notThis? boolean -- if false, sets dirty=true
function GraphicsRect:noteDirty(notThis)
    if not notThis then
        self.dirty = true
    end
    if self.parent then
        self.parent.children_dirty[self.parent_index] = true
        if not self.parent.children_dirty_any then
            self.parent.children_dirty_any = true
            self.parent:noteDirty(true)
        end
    end
end

---comment
---@param graphicsDraw_nonlocal GraphicsDraw
function GraphicsRect:_draw(graphicsDraw_nonlocal, force)
    local graphicsDraw = graphicsDraw_nonlocal:inside(self)
    if self.dirty or force then
        self:draw(graphicsDraw)
        self.dirty = false
        force = true
    end
    if self.children_dirty_any or force then
        local children_dirty = force and self.children or self.children_dirty -- if force, then all children are drawn
        for i, _ in pairs(children_dirty) do
            self.children[i]:_draw(graphicsDraw, force)
            self.children_dirty[i] = nil
        end
        self.children_dirty_any = false
    end
end

---internal when clicked.
---@param x number
---@param y number
---@param button number
---@param playerName string
---@return boolean consumed
function GraphicsRect:_onClick(x, y, button, playerName)
    x = x - self.x
    y = y - self.y
    if not (0 <= x and x < self.w and 0 <= y and y < self.h) then
        return false
    end
    for i, child in pairs(self.children) do
        local consumed = child:_onClick(x, y, button, playerName)
        if consumed then
            return true
        end
    end
    return self:onClick(x, y, button, playerName)
end

--- overload this.
---@param graphicsDraw GraphicsDraw
function GraphicsRect:draw(graphicsDraw)
    -- temp function:
    graphicsDraw:fill(" ")
    graphicsDraw:set(0, 0, string.rep("^", self.w), 0x00FF70)
    graphicsDraw:set(0, self.h - 1, string.rep("_", self.w), 0x00FF70)
    graphicsDraw:set(0, self.h, string.rep("x", self.w), 0x00FF70) -- this shouldn't be visible
end

--- overload this. return if the click is consumed.
---@param x number
---@param y number
---@param button number
---@param playerName string
---@return boolean consumed
function GraphicsRect:onClick(x, y, button, playerName)
    return false -- unimplemented
end

return GraphicsRect
