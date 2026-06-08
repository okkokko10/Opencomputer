
-- local my_variables = require "/okko.integrated.my_variables"

local ExposedVariable = require "/okko.Variables.ExposedVariable"

ExposedVariable:link("ship.propeller.left",nil,false,true)
ExposedVariable:link("ship.propeller.right",nil,false,true)
ExposedVariable:link("ship.balloon.one",nil,false,true)
ExposedVariable:link("ship.balloon.two",nil,false,true)

ExposedVariable:run_display()