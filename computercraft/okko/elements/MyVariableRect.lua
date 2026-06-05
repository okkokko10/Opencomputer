local BaseElement = require "okko.elements.BaseElement"
local BaseVariableRectElement = require "okko.elements.BaseVariableRectElement"
local Variable = require "okko.elements.Variable"
local VisibleVariableRect = require "okko.elements.VisibleVariableRect"
local TextElement = require "okko.elements.TextElement"
local FillElement = require "FillElement"

 
local vx = Variable:create(16,2)
local vy = Variable:create(16,5)

local MyVariableRect = VisibleVariableRect:create(
    BaseVariableRectElement:create(vx,vy),
    FillElement:create("x", "3", "45"), TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}}):defineCenter(2,2)
)
return MyVariableRect
