local BaseElement = require "/okko.elements.BaseElement"
local BaseVariableRectElement = require "/okko.elements.BaseVariableRectElement"
local Variable = require "/okko.elements.Variable"
local VisibleVariableRect = require "/okko.elements.VisibleVariableRect"
local TextElement = require "/okko.elements.TextElement"
local FillElement = require "/okko.elements.FillElement"

local MyVariableRect = VisibleVariableRect:new()



function MyVariableRect:create(vx,vy)
    return VisibleVariableRect:create(
    BaseVariableRectElement:create(vx,vy),
    FillElement:create("x", "3", "45"), TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}}):defineCenter(2,2)
)
end
return MyVariableRect
