
local pretty = require"cc.pretty"

if not commands then
    print("commands not available!")
    return
end

---@class Location: vector

local cod = {}

function cod.local_pos_format(pos)
    return string.format("~%f ~%f ~%f",pos.x,pos.y,pos.z)
end


---@param pos Location
function cod.particle(pos)
    commands.particle("minecraft:bubble " .. cod.local_pos_format(pos))
end

function cod.point(pos)
    local comm = "tp @e[name='pointer'] ".. cod.local_pos_format(pos)
    print(comm)
    local succ, outp, times = commands.exec(comm)
    print("->",pretty.pretty(outp))
end
function cod.create_pointer()
    commands.exec(
    '/summon armor_stand ~ ~ ~ {Invisible:1b,NoGravity:1b,'..
    'Silent:1b,Glowing:1b,ArmorItems:[{},{},{},{id:"minecraft:stone",count:1}],CustomName:"pointer"}')


    
end

function cod.sustain(pos)
    for i = 1, 10 do
        sleep(0.1)
        cod.particle(pos)
    end
end

-- cod.sustain(vector.new(0,2,0))


function cod.tri()
    local tri = require "/okko/trilaterate"
    for i = 1, 100 do
        sleep(0.1)
        local pos = tri.execute()
        print(pos)
        cod.point(pos)
        -- cod.particle(pos)

    end
end

if select(1,...) == "pointer" then
    cod.create_pointer()
end

cod.tri()


return cod