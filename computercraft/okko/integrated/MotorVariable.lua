local Variable = require "/okko.elements.Variable"


local MotorVariable = {}

---comment
---@param coll {rev: Variable, speed: Variable, forw: Variable}
function MotorVariable.create(coll)
    local var = Variable:createInterval(-7,7,0)
    var:addCallback(function (v)
        local val = v:getInterval()
        if val < 0 then
            coll.rev:setInterval(15)
            coll.forw:setInterval(0)
        end
        if val > 0 then
            coll.rev:setInterval(0)
            coll.forw:setInterval(15)
        end
        if val == 0 then
            coll.rev:setInterval(0)
            coll.forw:setInterval(0)
        end
        coll.speed:setInterval(14-math.abs(val)*2)
    end)
    return var
end
return MotorVariable