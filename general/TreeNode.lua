local Helper = require "Helper"
--- described in ideas.md around line 230,340
--- ability to store in a file efficiently not yet implemented

---@class TreeNode
---@field parent TreeNode|nil
---@field key any
---@field children table<any,TreeNode>?
---@field sums number[] -- a sequence with trailing 0s removed
---@field extra table? -- immutable
local TreeNode = {}

TreeNode.__index = TreeNode

--- todo: tag to delete entries with 0 sums?
--- todo: clean up
---@generic N: TreeNodeClass
---@generic Lower: TreeNodeClass
---@generic Higher: TreeNodeClass
---@class TreeNodeClass: TreeNode --, {name: `N`}
---@field name `N`
---@field lowerMetatable TreeNodeClass | .Lower
---@field higherMetatable? TreeNodeClass | .Higher
local TreeNodeClass = TreeNode

---@generic Name: TreeNodeClass
---@param name `Name`
---@return TreeNodeClass | Name
function TreeNode:createRootClass(name)
    local out = setmetatable({name = name}, self)
    out.__index = out
    ---@cast out TreeNodeClass
    return out
end

---comment
---for class
---@generic Name: TreeNodeClass
---@param self TreeNodeClass|any
---@param name `Name`
---@return TreeNodeClass | Name
function TreeNodeClass:createLowerClass(name)
    self.lowerMetatable = setmetatable({higherMetatable = self, name = name}, getmetatable(self))
    self.lowerMetatable.__index = self.lowerMetatable
    return self.lowerMetatable
end

---comment
---for a class to use
---@param self TreeNodeClass|any
---@param sumsLength? integer
---@return TreeNode
function TreeNodeClass:createRoot(sumsLength)
    local sums = {}
    -- for i = 1, sumsLength do
    --     sums[i] = 0
    -- end
    return setmetatable({sums = sums, parent = nil, key = nil}, self)
end

function TreeNode:getLowerMetatable()
    return self --[[@as TreeNodeClass]].lowerMetatable or assert(self --[[@as TreeNodeClass]].lowerMetatable)
end

---comment
---@return string
function TreeNode:getLayerName()
    return self --[[@as TreeNodeClass]].name
end

function TreeNode:makeChild(sums, key)
    return setmetatable({sums = sums, parent = self, key = key}, self:getLowerMetatable())
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
        if sums then
            chi:addSums(sums)
        end
        return chi
    else
        if sums then
            self:addSums(sums)
        else
            sums = {}
        end

        local out = self:makeChild(sums, key)
        self.children[key] = out
        return out
    end
end

---adds added to target in place.
---@param target number[]
---@param added number[]
function TreeNode.sumAdd(target, added)
    local lastNonzero = 0
    for i = 1, #added do -- todo: make sure addSums is a sequence
        local x = (target[i] or 0) + added[i]
        target[i] = x
        if (x ~= 0) then
            lastNonzero = i
        end
    end
    for i = lastNonzero + 1, #added do -- this way sums stays a sequence
        target[i] = nil
    end
end

function TreeNode:addSums(sums)
    TreeNode.sumAdd(self.sums, sums)
    if self.parent then
        self.parent:addSums(sums)
    end
    return self
end

---the path of this tree node, reversed.
---@return table
function TreeNode:pathReverse()
    if self.parent then
        local out = self.parent:pathReverse() -- this implementation means this cannot be memoized. and it shouldn't be.
        out[#out + 1] = self.key
        return out
    else
        return {}
    end
end
---the path of this tree node
---@return table
function TreeNode:path()
    local out = {}
    local pathReverse = self:pathReverse()
    for i = #pathReverse, 1, -1 do
        out[#out + 1] = pathReverse[i]
    end
    return out
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

function TreeNode.Itemclass()
    local Item_Class = TreeNode:createRootClass("Items")

    local Item_mod = Item_Class:createLowerClass("mod")
    local Item_name = Item_mod:createLowerClass("name")
    local Item_meta = Item_name:createLowerClass("meta")
    local Item_label = Item_meta:createLowerClass("label")
    ---@class hash: TreeNodeClass
    local Item_hash = Item_label:createLowerClass("hash")
    local Item_pos = Item_hash:createLowerClass("pos")

    ---setExtra
    ---@param hasTag any
    ---@param maxDamage any
    ---@param maxSize any
    ---@return TreeNode
    function Item_hash:setInfo(hasTag, maxDamage, maxSize)
        self.extra = {hasTag, maxDamage, maxSize}
        return self
    end
    return Item_Class
end

function TreeNode.ItemTest()
    -- ---@class Item_Class: TreeNodeClass
    local Item_Class = TreeNode.Itemclass()

    local Item_root = Item_Class:createRoot(3)

    --{size=1,slot=11,uitem={
    --"opencomputers:material",24,"Drone Case (Tier 2)",false,0,64,"690307fa128b0cbafe10166930e179e13133b713a34e20e7f888ed8d009696d7"
    local Case =
        Item_root:makeLevel("opencomputers"):makeLevel("material"):makeLevel(24):makeLevel("Drone Case (Tier 2)"):makeLevel(
        "690307fa128b0cbafe10166930e179e13133b713a34e20e7f888ed8d009696d7"
    ) --[[@as hash]]:setInfo(false, 0, 64):makeLevel("1 11", {1, 0, 0})
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
    ) --[[@as hash]]:setInfo(true, 0, 1):makeLevel("1 36", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        1,
        "OpenOS (Operating System)",
        "144cabf949191f132a8d3c6fec8e36885402c4f90b199b2b27ba83ea2c900955"
    ) --[[@as hash]]:setInfo(true, 0, 64):makeLevel("1 37", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        1,
        "OPPM (Package Manager)",
        "7ea4ed3bef6d5e1ef860a43099c13b840b2d6d851c5268fe135067a0645d9856"
    ) --[[@as hash]]:setInfo(true, 0, 1):makeLevel("1 40", {1, 0, 0})
    Item_root:forceElement(
        "opencomputers",
        "storage",
        4,
        "Hard Disk Drive (Tier 3) (4MB)",
        "1314bf812d9ecdbb369d9a298f4481e4e2e6fa114315a492d81e6d83a96fdfcc"
    ) --[[@as hash]]:setInfo(true, 0, 1):makeLevel("1 23", {1, 0, 0})
    Item_root:forceElement(
        "minecraft",
        "stained_glass_pane",
        5,
        "Lime Stained Glass Pane",
        "d0dafe9210a8d63439010f83cdaf7ffdc27f27022067d78d16aeb3702b925d47"
    ) --[[@as hash]]:setInfo(false, 0, 64):makeLevel("1 21", {1, 0, 0})
    Item_root:forceElement(
        "minecraft",
        "iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ) --[[@as hash]]:setInfo(false, 0, 64):makeLevel("1 47", {61, 0, 0})
    Item_root:forceElement(
        "minecraft",
        "iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ) --[[@as hash]]:setInfo(false, 0, 64):makeLevel("1 50", {6, 0, 0})
    Item_root:forceElement(
        "minecraft",
        "iron_ingot",
        0,
        "Iron Ingot",
        "d737e80b34af245d936ea83ff0eed2de4e9426ddc3cab71d1f5818263adeed73"
    ) --[[@as hash]]:setInfo(false, 0, 64):makeLevel("1 52", {47, 0, 0})

    return Case == Case2, Case, Item_root
end

---comment
---@param indent string
---@param indentAdd string
---@return string
function TreeNode:show(indent, indentAdd)
    indent = indent or "\t"
    indentAdd = indentAdd or "  "
    local sums = table.concat(self.sums, " ")
    local outhead =
        sums ..
        indent ..
            tostring(self.key) ..
                "    " ..
                    (self:getLayerName() or "") .. "  " .. table.concat(Helper.map(self.extra or {}, tostring), "|")
    local outtable = {}
    local nextIndent = indent .. indentAdd
    if self.children then
        for key, value in pairs(self.children) do
            outtable[#outtable + 1] = value:show(nextIndent, indentAdd)
        end
    end
    return outhead .. (outtable[1] and ("\n" .. table.concat(outtable, "\n")) or "")
end

---@class TreeNodeView: TreeNode
---@field real TreeNode
---@field parent TreeNodeView?
---@field key any
---@field children table<any,TreeNodeView>?
---@field sums number[]

---a view that is supposed to be like this one
---@return TreeNodeView
function TreeNode:makeView()
    ---@type TreeNodeView
    return setmetatable({real = self}, {__index = self})
end
---comment
---@return TreeNodeView
function TreeNode:makeChangedView()
    ---@type TreeNodeView
    return setmetatable({real = self}, {__index = self})
end

function TreeNode:representation() -- todo: add sums
    return self:path()
end

function TreeNode:matchesKey(key)
    return key == "%" or self.key == key --or string.match(tostring(self.key), key)
end

---comment
---arguments are treated as a sequence (arguments after the first nil are ignored)
---@param neededSums number[] -- todo: changed in place, if set, ends search when amount is reached (and limits sums of the last)
---@param key any
---@param nextKey any
---@param ... unknown
---@return TreeNodeView?
function TreeNode:matchingRecursive(neededSums, key, nextKey, ...)
    if self:matchesKey(key) then
        if not nextKey then -- matching ends
            return self:makeView()
        end
        local copy = self:makeChangedView()
        local sums = {}
        local newChildren = {}
        copy.children = newChildren
        copy.sums = sums
        if self.children then
            for k, child in pairs(self.children) do
                local newChild = child:matchingRecursive(neededSums, nextKey, ...)
                if newChild then
                    newChildren[k] = newChild
                    newChild.parent = copy
                    TreeNode.sumAdd(sums, newChild.sums)
                end
            end
        else
            TreeNode.sumAdd(sums, self.sums)
        end
        if next(sums) or next(newChildren) then -- next works as 'check nonempty'. todo: method
            return copy
        else
            return nil
        end
    else
        return nil
    end
end

function TreeNode:iterate(depth)
    error("unimplemented")
end

---comment
---@param parent TreeNode
---@param key any?
function TreeNode:deepCopy(parent, key)
    local out = parent:makeChild(Helper.shallowCopy(self.sums), key or self.key)
    out.extra = self.extra -- extra should be immutable
    if self.children then
        out.children = {}
        for key, value in pairs(self.children) do
            out.children[key] = value:deepCopy(out)
        end
    end
    return out
end

---if the node is fuzzy (child keys are equated), gets the key where the children are.
---otherwise returns falsey
---todo: this value is the first value
---@return string?
function TreeNode:isFuzzy()
    if self.children["&"] then
        return "&"
    else
        return nil
    end
end

---add deep copy of otherNode to this.
---@param otherNode TreeNode
function TreeNode:extend(otherNode)
    local self_name = self:getLayerName()
    local other_name = otherNode:getLayerName()
    assert(self_name == other_name, "mismatched layers: " .. self_name .. " =/= " .. other_name)

    TreeNode.sumAdd(self.sums, otherNode.sums)
    if otherNode.children then
        if not self.children then
            self.children = {}
        end
        local fuzz = self:isFuzzy()
        for key, value in pairs(otherNode.children) do
            key = fuzz or key
            if self.children[key] then
                self.children[key]:extend(value)
            else
                self.children[key] = value:deepCopy(self, key)
            end
        end
    end
end

---comment
---@param allItems table<itemIndex, ItemFoundAt>
function TreeNode:getFromOldAllItems(allItems)
    local Item_Class = TreeNode.Itemclass()
    local Item_root = Item_Class:createRoot()
    for key, item in pairs(allItems) do
        local mod_name, meta, label, hasTag, maxDamage, maxSize, hash = table.unpack(item.uitem)
        local mod, name = string.match(mod_name, "^(.-)%:(.-)$")
        local sameItem = Item_root:forceElement(mod, name, meta, label, hash) --[[@as hash]]
        sameItem:setInfo(hasTag, maxDamage, maxSize)
        for key, foundAt in pairs(item.foundAtList) do
            sameItem:makeLevel(tostring(foundAt[1]) .. " " .. tostring(foundAt[2]), {foundAt[3]})
        end
    end
    return Item_root
end

return TreeNode
