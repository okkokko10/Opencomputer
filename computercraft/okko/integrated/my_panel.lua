local BaseElement = require "/okko.elements.BaseElement"
local TextElement = require "/okko.elements.TextElement"

local RootElement = require "/okko/elements/RootElement"
local MyVariableRect = require "/okko/elements/MyVariableRect"

local my_variables = require "/okko/integrated/my_variables"

-- local pretty = require "cc.pretty"
-- local f = fs.open(fs.combine(shell.dir(), "myvars.txt"),"w")


-- local tex = pretty.render(pretty.pretty(my_variables),25)
-- f.write(tex)
-- f.close()

local root = RootElement:create(term.current())




root:addChild(MyVariableRect:create(my_variables.left,my_variables.right)):setPosition(2,1)

root:addChild(TextElement:create({{"x","1", "2"}}):setPosition(5,5))

-- root:addChild(MyVariableRect:create(my_variables.left,nil):setPosition(2,2))
-- root:addChild(MyVariableRect:create(my_variables.right,nil):setPosition(2,6))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,3))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,7))

-- todo: numbered lines

root:addChild(MyVariableRect:create(nil,my_variables.balloon.one):setPosition(35,1))

root:rec_render()
print(term.getSize())

root:loop()