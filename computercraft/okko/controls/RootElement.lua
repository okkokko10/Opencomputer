local BaseElement = require "BaseElement"

---@class RootElement: BaseElement
---@field parent_window unknown
local RootElement = BaseElement:new()

function RootElement:getParentWindow(wish_width,wish_height)
    return self.parent_window
end


---@param window any
---@return RootElement
function RootElement:create(window)
    return self:new({parent_window=window})
end
return RootElement