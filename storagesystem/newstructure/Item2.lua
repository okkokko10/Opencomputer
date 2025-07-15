---@class Item2: table
---@field modname string
---@field name string
---@field meta integer
---@field label string
---@field hash string
---@field stacksize integer
---@field hasTag boolean
---@field maxDamage integer
---@field extra string
local Item2 = {}

function Item2:makeRepresentation()
    return self.modname ..
        "\1" ..
            self.name ..
                "\2" ..
                    self.meta ..
                        "\3" ..
                            self.label ..
                                "\4" ..
                                    self.hash .. "\5" .. self.stacksize .. "\6" .. self.maxDamage .. "\7" .. self.extra
end

---comment
---@param representation string
---@param label string
---@return boolean
function Item2.representationMatchesLabel(representation, label)
    return string.find(representation:match("\3(.-)\4"), label, nil, true) and true or false
end

---comment
---@param representation string
---@return any
function Item2:matchesRepresentation(representation)
end
