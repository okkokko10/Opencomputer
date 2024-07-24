local Helper = require "Helper"
local Nodes = require "navigation_nodes"

-- {nodeparent=, x=, y=, z=}
-- class for locations connected to a navigation node. a node also happens to be a Location.
local Location = {}

--- shorthand for fetch_api.actions.moveto
---@param self table Location
function Location.moveto(self)
  return {
    type = "moveto",
    x = self.x,
    y = self.y,
    z = self.z
  }

end
--- returns list of moveto commands to move from Location self to Location other
---@param self table Location
---@param other table Location
---@return table|nil
function Location.pathfind(self, other)
  -- might repeat positions at the start and end
  local pathids = Nodes.pathbetween(self.nodeid or Nodes.parent(self), other.nodeid or Nodes.parent(other))
  if not pathids then
    return -- no path available
  end
  local pathloc = Helper.map(pathids, function(id)
    return Location.moveto(Nodes.get(id))
  end)
  pathloc[#pathloc + 1] = Location.moveto(other)
  return pathloc
end

--- modifies target: copies location data of base to target. leave nil to get a new copy
---@param base table Location
---@param target table|nil Location
---@return table target
function Location.copy(base, target)
  target = target or {}
  target.nodeparent = Nodes.parent(base)
  target.x = base.x
  target.y = base.y
  target.z = base.z
  return target
end

return Location
