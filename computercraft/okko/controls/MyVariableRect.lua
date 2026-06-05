local BaseElement = require "BaseElement"
local BaseVariableRectElement = require "BaseVariableRectElement"
local Variable = require "Variable"
local VisibleVariableRect = require "VisibleVariableRect"
local TextElement = require "TextElement"

 
local vx = Variable:create(16,2)
local vy = Variable:create(16,5)

local MyVariableRect = VisibleVariableRect:create(
    BaseVariableRectElement:create(vx,vy), TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}},3,3)
)
return MyVariableRect
