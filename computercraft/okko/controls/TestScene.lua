local BaseElement = require "BaseElement"
local RootElement = require "RootElement"

local MyVariableRect = require "MyVariableRect"

local root = RootElement:create(term.current())

root:addChild(MyVariableRect)

root:rec_render()