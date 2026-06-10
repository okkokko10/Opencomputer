local Variable = require "/okko.Variables.Variable"
local NumberVariable = require "/okko.Variables.NumberVariable"
local BijectionVariable = require "/okko.Variables.BijectionVariable"




local autopilot = {}



autopilot.wish_orientation = nil
autopilot.wish_rotation = 0

function autopilot.rotateLeft()
    
end

local pretty = require "cc.pretty"

function autopilot.balloonVariable(balloons,capacities)
    local capacity = 0
    -- local current = 0
    for key, value in pairs(capacities) do
        capacity = capacity + value
    end
    local bal = NumberVariable:create(nil,0,capacity)
    BijectionVariable.makeMultiConnection(bal,balloons,function (origins,many,one)
        local current = 0
        for key, value in pairs(many) do
            current = current + value:get() * capacities[key]
        end
        current = current / 15
        -- print("setting one", current)
        one:set(current,origins)

    end,
    function (origins,one,many)
        local temp = {}
        local current = 0
        local target = one:get() * 15
        for key, value in pairs(many) do
            temp[key] = value:get() or 0
            current = current + temp[key] * capacities[key]
        end
        local difference = current - target
        local works = true
        -- can be optimized
        local function test(key)

            local sign = (difference < 0) and 1 or -1
            -- print("| " .. key .. " " .. temp[key] .. " " .. difference)
            if (sign < 0 and temp[key] <= 0) or (sign > 0 and temp[key] >= 15) then
                return
            end
            -- print((difference + sign * capacities[key]))
            if math.abs(difference + sign * capacities[key]) < math.abs(difference) then
                -- print(":: " .. key .. " " .. temp[key])
                works = true
                temp[key] = temp[key] + sign
                difference = difference + sign * capacities[key]
            end
        end
        while works and not (difference == 0) do
            works = false
            for key, value in pairs(temp) do
                test(key)
            end
        end
        for key, value in pairs(many) do
            origins[value:getID()] = nil -- fix
            value:set(temp[key],origins)
        end
        -- pretty.pretty_print(many)
        -- print ("set many, ", difference)
        -- pretty.pretty_print(temp)
        -- print(one:getID(),many.one:getID(),many.two:getID())
        -- pretty.pretty_print(origins)




    end)
    return bal
end

function autopilot.getBalloonForHeight(height)
    local pressure = aero.getAirPressure(vector.new(0,height,0))
    if pressure == 0 then
        return math.huge
    end
    local mass = sublevel.getMass()
    local scalar = 1.5
    local mass_per_balloon = scalar * pressure
    local wish_balloon = mass / mass_per_balloon
    return wish_balloon
end
function autopilot.wishHeight(balloonVariable)
    return NumberVariable:create(nil,-64,400):addCallback(function (origins,v)
        local wish = autopilot.getBalloonForHeight(v:get())
        balloonVariable:set(wish,origins)
    end)
end

autopilot.front = vector.new(0,0,1)

function autopilot.apply_orientation(front)
    if autopilot.wish_position then
        local logicalPose = sublevel.getLogicalPose()
        local position = logicalPose.position
        position.y = autopilot.wish_position.y

        autopilot.wish_orientation = (autopilot.wish_position - position)
        local length =  autopilot.wish_orientation:length()
        autopilot.wish_orientation = autopilot.wish_orientation / length
        local orientation = logicalPose.orientation
        local quarter = quaternion.fromEuler(0,math.pi*0.25,0)
        local rotated = autopilot.wish_orientation
        local angl = rotated:dot(orientation * (front or autopilot.front))
        autopilot.wish_rotation = angl
        print("angl: ", angl)
        -- local rotation = sublevel.getAngularVelocity().y
        -- autopilot.wish_rotation_accel = angl
        return length
    end
    return 0
end


-- function autopilot.setHeight(height)

-- end

return autopilot