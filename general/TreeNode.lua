--- described in ideas.md around line 230,340
--- ability to store in a file efficiently not yet implemented

---@class TreeNode
---@field parent TreeNode|nil
---@field key any
---@field children table<any,TreeNode>
---@field sums number[]
---@field extra table
local TreeNode = {}

TreeNode.__index = TreeNode

---comment
---@param sumsLength integer
---@return TreeNode
function TreeNode.createRoot(sumsLength)
    local sums = {}
    for i = 1, sumsLength do
        sums[i] = 0
    end
    return setmetatable({sums = sums, parent = nil, key = nil}, TreeNode)
end

--- todo: rename
---makes a lower level. gets the old one if key already exists
---self:makeLevel(key,sums) is shorthand for self:makeLevel(key):addSums(sums)
---@param key any
---@param sums? number[]
---@return TreeNode
function TreeNode:makeLevel(key, sums)
    if not self.children then
        self.children = {}
    end
    local chi = self.children[key]
    if chi then
        chi:addSums(sums)
        return chi
    else
        if sums then
            self:addSums(sums)
        else
            sums = {}
            for i = 1, #self.sums do
                sums[i] = 0
            end
        end

        local out = setmetatable({sums = sums, parent = self, key = key}, TreeNode)
        self.children[key] = out
        return out
    end
end

function TreeNode:addSums(sums)
    for i = 1, #self.sums do
        self.sums[i] = self.sums[i] + sums[i]
    end
    if self.parent then
        self.parent:addSums(sums)
    end
    return self
end

---the path of this tree node
---@return table
function TreeNode:path()
    if self.parent then
        local out = self.parent:path() -- this implementation means this cannot be memoized. and it shouldn't be.
        out[#out + 1] = self.key
        return out
    else
        return {}
    end
end

---returns an element in the tree with the key
---@param key any
---@param ... unknown
---@return TreeNode|nil
function TreeNode:element(key, ...)
    if key then
        return self.children[key] and (self.children[key]:element(...))
    else
        return self
    end
end

---like element, but creates such element if it does not exist
---@param key any
---@param ... unknown
---@return TreeNode
function TreeNode:forceElement(key, ...)
    if key then
        return self:makeLevel(key):forceElement(...)
    else
        return self
    end
end
function TreeNode:setExtra(...)
    self.extra = {...}
    return self
end

function TreeNode.ItemTest()
    ---setExtra
    ---@param hasTag any
    ---@param maxDamage any
    ---@param maxSize any
    ---@return TreeNode
    function TreeNode:setInfo(hasTag, maxDamage, maxSize)
        self.extra = {hasTag, maxDamage, maxSize}
        return self
    end
    local Item_root = TreeNode.createRoot(3)
    -- local Item_meta = Item_root:makeLevel()
    -- local Item_label = Item_meta:makeLevel()
    -- local Item_hash = Item_label:makeLevel()
    -- local Item_stack = Item_hash:makeLevel()

    --{size=1,slot=11,uitem={
    --"opencomputers:material",24,"Drone Case (Tier 2)",false,0,64,"690307fa128b0cbafe10166930e179e13133b713a34e20e7f888ed8d009696d7"
    local Case =
        Item_root:makeLevel("opencomputers"):makeLevel("material"):makeLevel(24):makeLevel("Drone Case (Tier 2)"):makeLevel(
        "690307fa128b0cbafe10166930e179e13133b713a34e20e7f888ed8d009696d7"
    ):setInfo(false, 0, 64):makeLevel("1 11", {1, 0, 0})
    local Case2 =
        Item_root:forceElement(
        "opencomputers",
        "material",
        24,
        "Drone Case (Tier 2)",
        "690307fa128b0cbafe10166930e179e13133b713a34e20e7f888ed8d009696d7",
        "1 11"
    )
    Item_root:forceElement(
        "opencomputers",
        "storage",
        1,
        "OpenOS (Operating System)",
        "e9ae938fc77d49cbddecd5eeabbbece42ed0471a8fcf30f3734ab555dfd73078"
    ):setInfo(true, 0, 1):makeLevel("1 36", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        1,
        "OpenOS (Operating System)",
        "144cabf949191f132a8d3c6fec8e36885402c4f90b199b2b27ba83ea2c900955"
    ):setInfo(true, 0, 64):makeLevel("1 37", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        1,
        "OPPM (Package Manager)",
        "7ea4ed3bef6d5e1ef860a43099c13b840b2d6d851c5268fe135067a0645d9856"
    ):setInfo(true, 0, 1):makeLevel("1 40", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        4,
        "Hard Disk Drive (Tier 3) (4MB)",
        "1314bf812d9ecdbb369d9a298f4481e4e2e6fa114315a492d81e6d83a96fdfcc"
    ):setInfo(true, 0, 1):makeLevel("1 23", {1, 0, 0})
    Item_root:forceElement(
        "minecraft",
        "stained_glass_pane",
        5,
        "Lime Stained Glass Pane",
        "d0dafe9210a8d63439010f83cdaf7ffdc27f27022067d78d16aeb3702b925d47"
    ):setInfo(false, 0, 64):makeLevel("1 21", {1, 0, 0})
    Item_root:forceElement(
        "minecraft:iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ):setInfo(false, 0, 64):makeLevel("1 47", {61, 0, 0})
    Item_root:forceElement(
        "minecraft:iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ):setInfo(false, 0, 64):makeLevel("1 50", {6, 0, 0})
    Item_root:forceElement(
        "minecraft:iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ):setInfo(false, 0, 64):makeLevel("1 52", {47, 0, 0})

    return Case == Case2, Case, Item_root
end

return TreeNode
