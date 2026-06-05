
local name0 = "redstone_relay_0"
local name1 = "redstone_relay_1"

-- todo: it flashes the links and then asks the user to name them

return {
    left = {
        rev = {relay = name0, side = "back"},
        on = {relay = name0, side = "left"},
        forw = {relay = name0, side = "front"},
},
    right = {
        rev = {relay = name1, side = "left"},
        on = {relay = name0, side = "top"},
        forw = {relay = name0, side = "right"},
    },
}