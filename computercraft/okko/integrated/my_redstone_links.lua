
local name0 = "redstone_relay_0"
local name1 = "redstone_relay_1"

-- todo: it flashes the links and then asks the user to name them

---@class RedstoneRelaySide
---@field relay string
---@field side string

return {
    left = {
        compose_type = "motor",
        rev = {base_type = "redstone_relay_out", relay = name0, side = "back"},
        speed = {base_type = "redstone_relay_out", relay = name0, side = "left"},
        forw = {base_type = "redstone_relay_out", relay = name0, side = "front"},
},
    right = {
        compose_type = "motor",
        rev = {base_type = "redstone_relay_out", relay = name1, side = "left"},
        speed = {base_type = "redstone_relay_out", relay = name0, side = "top"},
        forw = {base_type = "redstone_relay_out", relay = name0, side = "right"},
    },
    balloon = {
        one = {base_type = "redstone_relay_out", relay = name1, side = "back"}
    }
}