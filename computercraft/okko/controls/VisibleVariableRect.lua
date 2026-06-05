local BaseElement = require "BaseElement"
local BaseVariableRectElement = require "BaseVariableRectElement"
local Variable = require "Variable"


---@class VisibleVariableRect: BaseElement
---@field board BaseVariableRectElement
---@field nub BaseElement
local VisibleVariableRect = BaseElement:new()


-- function VisibleVariableRect:onPostParentInit()
--     -- self:remakeWindow(self.vx and self.vx.range or 1, self.vy and self.vy.range or 1)
-- end





---@param board BaseVariableRectElement
---@param nub BaseElement
---@return VisibleVariableRect
function VisibleVariableRect:create(board,nub)
    local funcc = function (vx,vy)
        nub:setPosition(vx and vx:get() or 1, vy and vy:get() or 1)
    end
    Variable.addCallback(funcc,board:getVariables())
    
    local this = self:new({board=board, nub=nub})
    this:addChild(board)
    this:addChild(nub)
    funcc(board.vx,board.vy)
    return this
end
return VisibleVariableRect