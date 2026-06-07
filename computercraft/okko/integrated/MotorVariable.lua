local Variable = require "/okko.Variables.Variable"
local NumberVariable = require "/okko.Variables.NumberVariable"
local RedstoneVariable = require "/okko.Variables.RedstoneVariable"

local MotorVariable = {}


function MotorVariable.from_directional(speed,rev,forw)
    if not speed then -- if these have not initialized yet
        return
    end
    if ((forw == 0) == (rev == 0)) or speed == 15 then
        return 0
    end
    local a = 15-speed
    if rev == 0 then
        return a
    else
        return -a
    end    
end
function MotorVariable.to_directional(val)
    local speed = 15-math.abs(val)
    if val < 0 then
            return speed,15,0
        end
        if val > 0 then
            return speed,0,15
        end
        if val == 0 then
            return speed,0,0
        end
end


---comment
---@param coll {speed: RedstoneVariable, rev: RedstoneVariable, forw: RedstoneVariable}
function MotorVariable.motor(coll)
    local var = RedstoneVariable:var(MotorVariable.from_directional(coll.speed:get(),coll.rev:get(),coll.forw:get())) or 0
    var:addCallback(function (origins,v)
        local val = v:get()
        local s,r,f = MotorVariable.to_directional(val)
        coll.speed:set(s,origins)
        coll.rev:set(r,origins)
        coll.forw:set(f,origins)
    end)
    return var
end



function MotorVariable.from_nondirectional(gearshift,analog,flip)
    if not analog then
        return
    end

    local a = 15-analog
    if (gearshift == 0) ~= (flip == true) then
        return a
    else
        return -a
    end    
end
function MotorVariable.to_nondirectional(val,flip)
    local analog = 15-math.abs(val)
    if val < 0 == (flip == true) then
        return 15,analog
    else
        return 0,analog
    end

end


---@param coll {gearshift: RedstoneVariable, analog: RedstoneVariable, flip: boolean|nil}
function MotorVariable.motor_nondirectional(coll)
    local flip = not not coll.flip
    local var = RedstoneVariable:var(MotorVariable.from_nondirectional(coll.gearshift:get(),coll.analog:get(),flip)) or 0
    var:addCallback(function (origins,v)
        local val = v:get()
        local g,a = MotorVariable.to_nondirectional(val,flip)
        coll.gearshift:set(g,origins)
        coll.analog:set(a,origins)
    end)
    return var
end



local BuildVariable = require "/okko.Variables.BuildVariables"
BuildVariable.compose_types.motor = MotorVariable.motor
BuildVariable.compose_types.motor_nondirectional = MotorVariable.motor_nondirectional

return MotorVariable