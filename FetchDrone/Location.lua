local Helper = require "Helper"
local Nodes = require "navigation_nodes"

-- {nodeparent=, x=, y=, z=}
-- class for locations connected to a navigation node. a node also happens to be a Location.
local Location = {}

---todo: dimension

---@class Position
---@field x number
---@field y number
---@field z number

---@class Location: Position
---@field nodeparent NodeID?

--- shorthand for fetch_api.actions.moveto
---@param self Location
---@return DroneAction_moveto
function Location.moveto(self)
  return {
    type = "moveto",
    x = self.x,
    y = self.y,
    z = self.z
  }
end
--- do self and other have the same x, y and z attributes?
---@param self Position|nil
---@param other Position|nil
function Location.equals(self, other)
  return self and other and self.x == other.x and self.y == other.y and self.z == other.z
end

--- returns list of moveto commands to move from Location self to Location other
---@param self Location|Node
---@param other Location|Node
---@return DroneAction_moveto[]?
function Location.pathfind(self, other)
  -- might repeat positions at the start and end
  local pathids = Nodes.pathbetween(self.nodeid or Nodes.parent(self), other.nodeid or Nodes.parent(other))
  if not pathids then
    return nil -- no path available
  end
  if Location.equals(self, other) then
    return {} -- no motion is necessary. this goes after checking pathids to make sure the locations share a common root
  end
  local pathloc =
    Helper.map(
    pathids,
    function(id)
      return Location.moveto(Nodes.get(id))
    end
  )
  pathloc[#pathloc + 1] = Location.moveto(other)
  return pathloc
end

--- returns amount of nodes between self and other. returns math.huge if they are disconnected
---@param self Location
---@param other Location
---@return number
function Location.pathDistance(self, other)
  local path = Location.pathfind(self, other)
  return path and Location.pathPathDistance(path) or math.huge
end

--- length of a path in space. not necessarily euclidean distance.
---@param path Position[]
function Location.pathPathDistance(path)
  return #path
end

--- modifies target: copies location data of base to target. leave nil to get a new copy
---@param base Location
---@param target? Location
---@return Location target
function Location.copy(base, target)
  target = target or {}
  target.nodeparent = Nodes.parent(base)
  target.x = base.x
  target.y = base.y
  target.z = base.z
  return target
end

return Location
