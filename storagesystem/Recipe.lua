local Item = require "Item"
local inventoryhigh = require "inventoryhigh"

---@class Recipe
---@field outputItem Item
---@field needed Item[] -- no repeats
---@field stationType string
---@field using [integer,integer][][] -- using[i] is a list of [index,size], which tells where needed[i] is spread
---@field extra any
local Recipe = {}

--[[
recipe: {
  outputItem: Item, -- with size
  needed= {
    item,item... -- with size
  },
  stationType: string,
  using= {
    ... -- station specific. for crafting tells what slots items go into
  },
  extra: any -- station specific
}

stationType: {
  fun(stationInstance)
}

station: {
}

]]
--- todo, dummy
---@param item Item
---@return Recipe?
function Recipe.getRecipe(item)
  -- todo, dummy
  return
end

function Recipe:CraftNaive()
end

---non-recursively
---@param times integer
---@return Future
function Recipe:CraftSelf(times)
end

function Recipe:FindNeeded()
end

return Recipe
