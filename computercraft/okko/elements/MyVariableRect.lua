local BaseElement = require "/okko.elements.BaseElement"
local BaseVariableRectElement = require "/okko.elements.BaseVariableRectElement"
local Variable = require "/okko.Variables.Variable"
local VisibleVariableRect = require "/okko.elements.VisibleVariableRect"
local TextElement = require "/okko.elements.TextElement"
local FillElement = require "/okko.elements.FillElement"

local MyVariableRect = VisibleVariableRect:new()

local function mapArgs(func,...)
    local a = table.pack(...)
    local b = {}
    for i = 1,a.n do
        b[i] = func(a[i])
    end
    return table.unpack(b,1,a.n)
end

---comment
---@param vx? Variable
---@param vy? Variable
---@return BaseElement
function MyVariableRect:create(vx,vy)
    local function vline(v)
        return v and {
        v:bijection(function (x)
            return tostring(x)
        end), "3","8"
    } or "."
    end
    local touch = BaseVariableRectElement:create(vx,vy)
    return BaseElement:new()
        :addChild(
            touch
        )
        :addChild(
            FillElement:create("x", "300", "45"):setSize(touch:getSize())
        )
        :addChild(
            TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}, vline(vx),vline(vy)})
            :defineCenter(2,2):setPosition(vx and vx:visual() or 1,vy and vy:visual() or 1)
        )

--     return VisibleVariableRect:create(
--     BaseVariableRectElement:create(vx,vy),
--     FillElement:create("x", "300", "45"), 
--     TextElement:create({{" | ", " 1 "},{"-x-","121"," 3 "}, {" | ", " 1 "}, vline(vx),vline(vy)}):defineCenter(2,2)
-- )
end
return MyVariableRect
