

---@class Variable
---@field range number
---@field callbacks fun()[]
local Variable = {range = 1, value = 1}
function Variable:new(o)
      o = o or {}
      setmetatable(o, self)
      self.__index = self
      return o
end

function Variable:create(range,value)
    return self:new({range=range or 1,value=value or 1, callbacks = {}})
end

function Variable:set(value,silent)
    self.value = value
    if not silent then
        for index, value in ipairs(self.callbacks) do
            value()
        end
    end
end
function Variable:get(value)
    return self and self.value or 1
end



--- when the LAST non-null variable in the ... is set, func is called with each variable 
---
---@param func fun(...:Variable)
---@param ... Variable
function Variable.addCallback(func,...)
    local args = table.pack(...)
    local last
    for i = 1, args.n do
        if args[i] then
            last = args[i]
        end
    end
    last.callbacks[#last.callbacks+1] = function ()
        func(table.unpack(args))
    end
end


return Variable