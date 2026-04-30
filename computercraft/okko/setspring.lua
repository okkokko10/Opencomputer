local pretty = require "cc.pretty"
local function prnt(...)
    print(pretty.pretty(...))
end

local spr = peripheral.wrap("back")
local ang = peripheral.wrap("left")
prnt((spr))
prnt(ang)
local gca = ang.getClosestAngle()


local inp = " "

while
    inp ~= "q" do
    print(spr.isRunning(), spr.getLimit(), spr.getAngle())
    inp = read()
    n = tonumber(inp)
    if n then
        spr.setLimit(n)
    elseif inp ~= "" then
        print("not a number")
    end
end
