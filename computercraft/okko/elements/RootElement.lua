local BaseElement = require "/okko.elements.BaseElement"

---@class RootElement: BaseElement
---@field parent_window unknown
local RootElement = BaseElement:new()

-- function RootElement:getParentWindow(wish_width,wish_height)
--     return self.parent_window
-- end
-- function RootElement:onPostParentInit()

-- end

function RootElement:onPostAddChild(child)
    child:updateChildWindow(self.awindow)
end

---@param window any
---@return RootElement
function RootElement:create(window)
    return self:new({awindow=window})
end

local mouses = {
    ["mouse_click"] = true,
    ["mouse_drag"] = true,
    ["mouse_scroll"] = true,
    ["mouse_up"] = true,
}


function RootElement:loop()
    while true do
        local event, misc, x, y = os.pullEvent()
        if mouses[event] then
            self:mouseEventRaw(event,misc,x,y)
        end
        self.awindow.clear()
        self:rec_render()

    end
end


return RootElement