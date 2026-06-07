local BaseElement = require "/okko.elements.BaseElement"
local BaseVariableRectElement = require "/okko.elements.BaseVariableRectElement"
local Variable = require "/okko.Variables.Variable"


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
function VisibleVariableRect:create(board,seen_board,nub)
    local funcc = function (origins,vx,vy)
        nub:setCenter(vx and vx:getVisual() or 1, vy and vy:getVisual() or 1)
    end
    Variable.addCallbackGroup(funcc,board:getVariables())
    local this = self:new({board=board,seen_board = seen_board, nub=nub})
    this:addChild(board)
    this:addChild(seen_board:setSize(board:getSize()))
    this:addChild(nub)
    funcc(board.vx,board.vy)
    return this
end
return VisibleVariableRect