local BaseElement = require "/okko.elements.BaseElement"

print("imported BaseElement")
local RootElement = require "/okko.elements.RootElement"

print("imported RootElement")

local Variable = require "/okko.elements.Variable"
print("imported Variable")

local MyVariableRect = require "/okko.elements.MyVariableRect"
print("imported MyVariableRect")


local root = RootElement:create(term.current())
print("created root")

root:addChild(MyVariableRect:create(Variable:create(16,2),Variable:create(16,5)))
print("added child")

root:rec_render()
print("finished")

root:loop()