--- coordinate nodes in a tree that allow for drone navigation
local Helper = require "Helper"
local filehelp = require "filehelp"

---@alias NodeID number|string

---@class Node: Location
---@field nodeid NodeID

--- 3d coordinate nodes in a tree that allow for drone navigation
local Nodes = {}

Nodes.NODES_PATH = "/usr/storage/nodes.csv"

---@type table<NodeID,Node>
Nodes.nodes = filehelp.loadCSV(Nodes.NODES_PATH, "nodeid")

function Nodes.saveNodes()
  filehelp.saveCSV(Nodes.nodes, Nodes.NODES_PATH)
end

--- gets the parent of a node, with other fallback names. this way inventory data and Location also works
---@param target Location
function Nodes.parent(target)
  return target.nodeparent
end

--- gets a node by its id
---@param nodeid NodeID
---@return Node {nodeid=?,x=?,y=?,z=?,nodeparent=?}
function Nodes.get(nodeid)
  local temp = Nodes.nodes[nodeid]
  return temp
end

--- returns the path of node ids from root to this
---@param nodeid NodeID
---@return NodeID[]
function Nodes.treepath(nodeid)
  local node = Nodes.get(nodeid)
  if not Nodes.parent(node) then -- node is root
    return {nodeid}
  else
    local temp = Nodes.treepath(Nodes.parent(node))
    temp[#temp + 1] = nodeid
    return temp
  end
end

--- generates a path from node start to node finish, as node ids
---@param startID NodeID
---@param finishID NodeID
---@return NodeID[] | nil
function Nodes.pathbetween(startID, finishID)
  -- starts from root, then looks for the last common node. then paths through the difference
  if not startID or not finishID then
    return nil
  end
  local a = Nodes.treepath(startID)
  local b = Nodes.treepath(finishID)
  local j
  for i = 1, math.min(#a, #b) do
    if a[i] ~= b[i] then
      j = i
      break
    end
  end
  j = j or math.min(#a, #b) + 1
  -- if j is nil, one node is part of the other's treepath

  if j == 1 then
    -- nodes have different roots, so there is no path available
    return nil
  end
  -- j-1 is the last common node
  local out = {}

  for i = #a, j, -1 do -- reversed a from end to index j
    out[#out + 1] = a[i]
  end
  for i = j - 1, #b do -- then b from j-1 to end
    out[#out + 1] = b[i]
  end
  return out

  --  1 2 3 4 5 6 7
  --  1 2 3 4 8 9
  --          ^
  --      7 6 5 4 8 9
  --  1 2 3 4 5 6 7
  --  1 2 3 4
  -- ^ j=nil
  --  1 2 3 4
  --  5 6 7 8
  --  ^ this should return nil
  --  1 2 3 4
  --  1 2 3 4 5 6 7
  -- ^ j=nil
  -- when startID and finishID are the same, just returns a single {finishID}
end

--- adds a new node
---@param nodeid? NodeID leave nil to automatically assign one
---@param x number
---@param y number
---@param z number
---@param nodeparent? NodeID
---@return NodeID
function Nodes.create(nodeid, x, y, z, nodeparent)
  nodeid = nodeid or #(Nodes.nodes) + 1
  Nodes.nodes[nodeid] = {
    nodeid = nodeid,
    x = x,
    y = y,
    z = z,
    nodeparent = nodeparent
  }
  Nodes.saveNodes()
  return nodeid
end

--- gets the closest node to the coordinates
---@param x number
---@param y number
---@param z number
---@return Node?
function Nodes.findclosest(x, y, z)
  local temp =
    Helper.min(
    Nodes.nodes,
    function(v, k)
      return (v.x - x) * (v.x - x) + (v.y - y) * (v.y - y) + (v.z - z) * (v.z - z)
    end
  )
  return temp
end

return Nodes
