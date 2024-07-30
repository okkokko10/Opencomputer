local Item = require "Item"



---@class Recipe
---@field outputItem Item
---@field needed Item[]
---@field machineType string
---@field using table
---@field extra any
local Recipe = {}

--[[
recipe: {
  outputItem: Item, -- with size
  needed= {
    item,item... -- with size
  },
  machineType: string,
  using= {
    ... -- machine specific. for crafting tells what slots items go into
  },
  extra: any -- machine specific
}

machineType: {
  fun(machineInstance)
}

machine: {
}

]]

--- todo, dummy
---@param item Item
---@return Recipe?
function Recipe.getRecipe(item)
  -- todo, dummy
  return
end

return Recipe

