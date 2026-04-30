local pretty = require "cc.pretty"
local function prnt(...)
    print(pretty.pretty(...))
end
local vn = require "visualize_num"

local spr = peripheral.wrap("back")
-- local ang = peripheral.wrap("left")
prnt((spr))
-- prnt(ang)
-- local gca = ang.getClosestAngle


local ninety = 90

local lim = 0

local function setOnDrag()
    local event, button, x, y = os.pullEvent("mouse_drag")
    lim = x / vn.hx * ninety
end
-- local function do_sleep() sleep(0.1) end
while true do
    parallel.waitForAny(function() sleep(0.1) end, setOnDrag)
    -- print(spr.isRunning(), spr.getLimit(), spr.getAngle())
    local w = spr.getLimit()
    local a = spr.getAngle()
    term.clear()
    -- term.scroll(-3)
    
    vn.blitXUnit(1,lim/ninety,tostring(math.floor(lim)),"a",".")
    vn.blitXUnit(2,w/ninety,tostring(math.floor(w)),"b",".")
    vn.blitXUnit(3,math.abs(a/ninety),tostring(math.floor(a)),"c",".")
    spr.setLimit(lim)
    
    
end
