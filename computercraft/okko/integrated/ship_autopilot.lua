
local ExposedVariable   = require "/okko.Variables.ExposedVariable"
local RedstoneVariable  = require "/okko.Variables.RedstoneVariable"
local NumberVariable    = require "/okko.Variables.NumberVariable"
local Variable          = require "/okko.Variables.Variable"


local autopilot = require "/okko.integrated.autopilot"

print("autopilot")

ExposedVariable:wrap(
function ()
print("wrap")
local balloons = {
    one = ExposedVariable:link("ship.balloon.one",RedstoneVariable:create(),true),
    two = ExposedVariable:link("ship.balloon.two",RedstoneVariable:create(),true)
    }
local capacities = {
    one = 2000,
    two = 5000
}
print("balloons")

local balloonVariable = autopilot.balloonVariable(balloons,capacities)
print("balloonVariable")
local wishHeight = autopilot.wishHeight(balloonVariable)
print("wishHeight")
ExposedVariable:register("ship.autopilot.balloon",balloonVariable,true)
print("register 1")
ExposedVariable:register("ship.autopilot.wishHeight",wishHeight,true)
print("register 2")



local speed = NumberVariable:create(0,-15,15)
local wish_position = Variable:create(false)
local distance = Variable:create(0)
local front = Variable:create(vector.new(0,0,1))

ExposedVariable:register("ship.autopilot.speed",speed,true)
ExposedVariable:register("ship.autopilot.wish_position",wish_position,true)
ExposedVariable:register("ship.autopilot.distance",distance,true)
ExposedVariable:register("ship.autopilot.front",front,true)

print("register 5")


local propeller_left = ExposedVariable:link("ship.propeller.left",NumberVariable:create(nil,-15,15),false)
local propeller_right = ExposedVariable:link("ship.propeller.right",NumberVariable:create(nil,-15,15),false)

print("propeller")

local pretty = require"cc.pretty"

while true do
    sleep(1)
    autopilot.wish_position = wish_position:get()
    local dist,angl = autopilot.apply_orientation(front:get())
    if speed:get() and speed:get() > 0 then
        local wre = math.min(1,dist/200)
        
        propeller_left:set(wre*speed:get()*math.min(1,1.1-autopilot.wish_rotation))
        propeller_right:set(wre*speed:get()*math.min(1,1.1+autopilot.wish_rotation)) 
    end
    distance:set(dist)
    print(autopilot.wish_position,dist,speed:get())
    -- pretty.pretty_print(autopilot.wish_position)
    
end




return true
end
)