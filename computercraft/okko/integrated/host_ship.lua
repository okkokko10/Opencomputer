
local my_variables = require "/okko.integrated.my_variables"

local ExposedVariable = require "/okko.Variables.ExposedVariable"

ExposedVariable:register("ship.propeller.left",my_variables.left,true)
ExposedVariable:register("ship.propeller.right",my_variables.right,true)
ExposedVariable:register("ship.balloon.one",my_variables.balloon.one,true)
ExposedVariable:register("ship.balloon.two",my_variables.balloon.two,true)
ExposedVariable:link("ship.autopilot.balloon",nil,false)
ExposedVariable:link("ship.autopilot.wishHeight",nil,false)

ExposedVariable:run_display(true)