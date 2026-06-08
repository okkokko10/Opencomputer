
local my_variables = require "/okko.integrated.my_variables"

local ExposedVariable = require "/okko.Variables.ExposedVariable"

ExposedVariable:register("ship.propeller.left",my_variables.left)
ExposedVariable:register("ship.propeller.right",my_variables.right)
ExposedVariable:register("ship.balloon.one",my_variables.balloon.one)
ExposedVariable:register("ship.balloon.two",my_variables.balloon.two)

ExposedVariable:run_display()