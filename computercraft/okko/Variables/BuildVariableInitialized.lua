local BuildVariable = require "/okko.Variables.BuildVariable"
local RedstoneVariable = require "/okko.integrated.RedstoneVariable"
local MotorVariable = require "/okko.integrated.MotorVariable"
BuildVariable.base_types.redstone_relay_out = RedstoneVariable.convert
BuildVariable.compose_types.motor = MotorVariable.create

return BuildVariable