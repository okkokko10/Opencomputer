local Item = require "Item"
local Helper = require "Helper"
local component = require "component"
local gpu = component.gpu

local function filterItem(item, filterstring)
  for str in Helper.splitString(filterstring, " ") do
    if str[1] == "@" then
      if not string.find(Item.getMod(item), string.sub(str, 2)) then
        return false
      end
    else
      if not string.find(Item.getlabel(item), str) then
        return false
      end
    end
  end
  return true
end

local GUI = {}

GUI.width = 120
GUI.areaHeight = 20
GUI.areaTop = 10

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

function GUI.showItems(itemlist, offset)
  gpu.set(1, GUI.areaTop, "--------------------------------------------------------------")
  for i = offset, offset + GUI.areaHeight do
    GUI.printItem(1, GUI.areaTop + i, itemlist[i])
  end
end

function GUI.display()

end
