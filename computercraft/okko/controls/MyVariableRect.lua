local BaseElement = require "BaseElement"
local BaseVariableRectElement = require "BaseVariableRectElement"
local Variable = require "Variable"
local VisibleVariableRect = require "VisibleVariableRect"
local TextElement = require "TextElement"
local FillElement = require "FillElement"

 
local vx = Variable:create(16,2)
local vy = Variable:create(16,5)

local MyVariableRect = VisibleVariableRect:create(
    BaseVariableRectElement:create(vx,vy),
    FillElement:create("x", "3", "45"), TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}}):defineCenter(2,2)
)
return MyVariableRect
