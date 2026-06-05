

---@class Variable
---@field range number
---@field callbacks fun()[]
---@field value number
---@field offset number
---@field raw_compose? table -- stores variables that are used in this
local Variable = {}
function Variable:new(o)
      o = o or {}
      setmetatable(o, self)
      self.__index = self
      return o
end

---comment
---@param range any
---@param value any
---@param offset any
---@return Variable
function Variable:create(range,value,offset)
    return self:new({range=range or 1,value=value or 1, offset = offset or 0, callbacks = {}})
end
function Variable:createInterval(min,max,value)
    return Variable:create(max-min+1,value-min+1,min-1)
end




function Variable:set(value,silent)
    self.value = value
    if not silent then
        for index, value in ipairs(self.callbacks) do
            value()
        end
    end
end
function Variable:get()
    return self and self.value or 1
end

function Variable:setVisual(value,silent)
    self:set(value,silent)
end
function Variable:getVisual()
    return self:get()
end



function Variable:getInterval()
    return self:get() + self.offset
end

function Variable:setInterval(value,silent)
    self:set(value - self.offset,silent)
end


--- when the LAST non-null variable in the ... is set, func is called with each variable 
---
---@param func fun(...:Variable)
---@param ... Variable
function Variable.addCallbackGroup(func,...)
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

---@param func fun(v: Variable)
---@return Variable
function Variable:addCallback(func)
    Variable.addCallbackGroup(func,self)
    return self
end


return Variable