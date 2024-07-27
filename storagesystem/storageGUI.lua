local Item = require "Item"
local Helper = require "Helper"
local component = require "component"
local gpu = component.gpu

local GUI = {}

GUI.width = 120
GUI.areaHeight = 20
GUI.areaTop = 10

GUI.itemlist = {}

--- items should be an output from InventoryHigh.allItems()
---@param items table
function GUI.setItems(items)
  GUI.itemlist = items
end

function GUI.printItem(x, y, item)
  if not item then
    return
  end
  local label = Item.getlabel(item)
  local mod = Item.getMod(item)
  local size = Item.getsize(item)
  local str = "" .. size .. " " .. label .. " (" .. mod .. ")"
  gpu.set(x, y, str)
end

--- do this after the other parts
---@param itemlist any
---@param offset any
function GUI.showItems(itemlist, offset)
  gpu.set(1, GUI.areaTop, "--------------------------------------------------------------")
  for i = offset, offset + GUI.areaHeight do
    GUI.printItem(1, GUI.areaTop + i, itemlist[i])
  end
end

function GUI.display()

end

--- each item row is its own element to press
