local BaseElement = require "okko.elements.BaseElement"

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
return RootElement