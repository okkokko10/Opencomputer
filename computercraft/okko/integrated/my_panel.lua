local BaseElement = require "/okko.elements.BaseElement"
local TextElement = require "/okko.elements.TextElement"
local RescaledVariable = require "/okko.Variables.RescaledVariable"

local RootElement = require "/okko.elements.RootElement"
local MyVariableRect = require "/okko.elements.MyVariableRect"

local my_variables = require "/okko.integrated.my_variables"

-- local pretty = require "cc.pretty"
-- local f = fs.open("/okko/integrated/myvars.txt","w")


-- local tex = pretty.render(pretty.pretty(my_variables),25)
-- f.write(tex)
-- f.close()

local root = RootElement:create(term.current())


-- todo: remote controls should link their variables, not

root:addChild(MyVariableRect:create(my_variables.left:rescale(0.25),my_variables.right:rescale(0.25)):setPosition(10,12))


-- root:addChild(MyVariableRect:create(my_variables.left,nil):setPosition(2,2))
-- root:addChild(MyVariableRect:create(my_variables.right,nil):setPosition(2,6))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,3))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,7))

-- todo: numbered lines


root:addChild(MyVariableRect:create(my_variables.right):setPosition(2,4))
root:addChild(MyVariableRect:create(my_variables.left):setPosition(2,2))

root:addChild(MyVariableRect:create(my_variables.balloon.two):setPosition(3,9))
root:addChild(MyVariableRect:create(my_variables.balloon.one):setPosition(3,7))

root:addChild(TextElement:create({"x"}):setPosition(7,8))


my_variables.left:updateCallbacks()
my_variables.right:updateCallbacks()
my_variables.balloon.one:updateCallbacks()
my_variables.balloon.two:updateCallbacks()

root:rec_render()
print(term.getSize())

root:loop()