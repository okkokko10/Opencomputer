local Variable = require "/okko.Variables.Variable"
-- local my_redstone_links = require "/okko.integrated.my_redstone_links"

---@class BuildVariable
---@field base_types {[string]:fun(coll:table):Variable}
---@field compose_types {[string]:fun(coll:table):Variable}
local BuildVariable = {base_types = {},compose_types = {}}



-- local pretty = require "cc.pretty"


function BuildVariable.convert_base(coll)
    local func = BuildVariable.base_types[coll.base_type]
    if not func then
        error("unknown base type: ", coll.base_type)
    end
    -- pretty.pretty_print(coll)
    local out = func(coll)
    out.raw_base = coll
    -- pretty.pretty_print(out)
    return out
end
function BuildVariable.convert_compose(coll)
    local func = BuildVariable.compose_types[coll.compose_type]
    if not func then
        error("unknown compose type: ", coll.compose_type)
    end
    -- pretty.pretty_print(coll)
    local out = func(coll)
    out.raw_compose = coll
    -- pretty.pretty_print(out)
    return out
end

--- coll is a nested table with RedstoneRelaySide at the leaves, or a RedstoneRelaySide
--- coll cannot contain "relay" unless it is a leaf
---@return Variable|{[string]:Variable|{[string]:Variable|table}}
function BuildVariable.convertNested(coll)
    if coll.base_type then
        return BuildVariable.convert_base(coll)
    end
    local out = {}
    for key, value in pairs(coll) do
        if type(value) == "table" then
            out[key] = BuildVariable.convertNested(value)
        else
            out[key] = value
        end
    end
    if out.compose_type then
        return BuildVariable.convert_compose(out)
    end
    
    -- pretty.pretty_print(out)
    -- sleep(0.1)
    return out
end
return BuildVariable