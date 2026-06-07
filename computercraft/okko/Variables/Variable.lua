
---@class CallbackOrigins
---@field [Variable] number
---@field n number


---@generic T
---@class Variable[T]
---@field callbacks fun(origins:CallbackOrigins)[]
---@field value T
---@field raw_compose? table -- stores variables that are used in this
local Variable = {}


function Variable:new(o)
      o = o or {}
      setmetatable(o, self)
      self.__index = self
      return o
end

---@generic T
---@param value T
---@return Variable[T]
function Variable:create(value)
    return self:new({value=value, callbacks = {}})
end


---sets the value, unless silent is a table that has this as a key.
---@generic T
---@param value T
---@param silent? CallbackOrigins|boolean
function Variable:set(value,silent)
    self:set_(value,silent)
end

function Variable:stampCallbackOrigins(origins)
    if origins[self] then
        return
    end
    origins.n = (origins.n or 0) + 1
    origins[self] = origins.n
    return true
end

---@generic T
---@param value T
---@param silent? CallbackOrigins|boolean
function Variable:set_(value,silent)
    if self.value == value then
        return
    end
    if type(silent) == "table" and silent[self] then
        return
    end
    self.value = value
    self:updateCallbacks(silent)
end

function Variable:updateCallbacks(silent)
    if silent ~= true then
        silent = silent or {}
        silent.n = (silent.n or 0) + 1
        silent[self] = silent.n
        for index, value in ipairs(self.callbacks) do
            value(silent)
        end
    end
    return self
    
end


---@generic T
---@return T
function Variable:get()
    return self.value
end



--- when the LAST non-null variable in the ... is set, func is called with each variable 
---
---@param func fun(origins:CallbackOrigins,...:Variable)
---@param ... Variable
function Variable.addCallbackGroup(func,...)
    local args = table.pack(...)
    local last
    for i = 1, args.n do
        if args[i] then
            last = args[i]
        end
    end
    last.callbacks[#last.callbacks+1] = function (origins)
        func(origins,table.unpack(args))
    end
end

--- the v variable is always self

---@generic Self
---@param self Self
---@param func fun(origins:CallbackOrigins,v: Variable)
---@return Self
function Variable:addCallback(func)
    Variable.addCallbackGroup(func,self)
    return self
end


---@generic T, To
---@param self Variable[To]
---@param toMapped fun(value:To):T
---@param toOriginal fun(value:T):To
---@return BijectionVariable[T,To]
function Variable:bijection(toMapped,toOriginal)
    require "/okko.Variables.BijectionVariable" -- changes this function
    return self:bijection(toMapped,toOriginal)
end


return Variable