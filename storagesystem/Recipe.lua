local Item = require "Item"

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

function Recipe.getRecipe(item)
  return -- todo, dummy
end

return Recipe

