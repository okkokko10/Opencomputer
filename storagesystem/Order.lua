--[[

Order types:
 do recipe x times (once ingredients are available)
 
 group of orders: every order must be possible (even if they influence each other) so that any goes through

Order instance and order class


Order: craft recipe

StateChange: like "item added to system", "item removed from system"


needed 

result



]]
---@class Order
---@field needed table
---@field results table
---@field complete boolean

local Order = {}

Order.__index = Order

function Order.create()
end
