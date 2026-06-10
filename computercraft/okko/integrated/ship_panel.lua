local BaseElement = require "/okko.elements.BaseElement"
local TextElement = require "/okko.elements.TextElement"
local RescaledVariable = require "/okko.Variables.RescaledVariable"
local ExposedVariable  = require "/okko.Variables.ExposedVariable"
local NumberVariable   = require "/okko.Variables.NumberVariable"

local RootElement = require "/okko.elements.RootElement"
local MyVariableRect = require "/okko.elements.MyVariableRect"


-- local pretty = require "cc.pretty"
-- local f = fs.open("/okko/integrated/myvars.txt","w")


-- local tex = pretty.render(pretty.pretty(my_variables),25)
-- f.write(tex)
-- f.close()

print("before wrap")

ExposedVariable:wrap( function ()

local root = RootElement:create(term.current())
print("root")

local propeller_left = ExposedVariable:link("ship.propeller.left",NumberVariable:create(nil,-15,15),true)
print("left")
local propeller_right = ExposedVariable:link("ship.propeller.right",NumberVariable:create(nil,-15,15),true)
local balloon_one = ExposedVariable:link("ship.balloon.one",NumberVariable:create(nil,0,15),true)
local balloon_two = ExposedVariable:link("ship.balloon.two",NumberVariable:create(nil,0,15),true)
print("all")

local speed = ExposedVariable:link("ship.autopilot.speed",NumberVariable:create(0,-15,15),false)
print("speed")

root:addChild(MyVariableRect:create(propeller_left:rescale(0.25),propeller_right:rescale(0.25)):setPosition(10,12))
print("1 child")

-- root:addChild(MyVariableRect:create(my_variables.left,nil):setPosition(2,2))
-- root:addChild(MyVariableRect:create(my_variables.right,nil):setPosition(2,6))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,3))
-- root:addChild(TextElement:create({{"^"}}):setPosition(17,7))

-- todo: numbered lines


root:addChild(MyVariableRect:create(propeller_right):setPosition(2,4))
root:addChild(MyVariableRect:create(propeller_left):setPosition(2,2))

root:addChild(MyVariableRect:create(balloon_two):setPosition(3,9))
root:addChild(MyVariableRect:create(balloon_one):setPosition(3,7))
root:addChild(MyVariableRect:create(speed):setPosition(3,11))

-- root:addChild(TextElement:create({"x"}):setPosition(7,8))


-- my_variables.left:updateCallbacks()
-- my_variables.right:updateCallbacks()
-- my_variables.balloon.one:updateCallbacks()
-- my_variables.balloon.two:updateCallbacks()

root:rec_render()
print(term.getSize())

root:loop()
end

)
