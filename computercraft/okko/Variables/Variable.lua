
---@class CallbackOrigins
---@field [Variable] number
---@field n number


---@generic T
---@class Variable[T]
---@field callbacks fun(origins:CallbackOrigins)[]
---@field value T
---@field raw_compose? table -- stores variables that are used in this
local Variable = {}

function Variable:generateID()
    return math.random()
end

function Variable:withID(id)
    self.variableID = id
    return self
end


function Variable:new(o)
      o = o or {}
      o.variableID = self:generateID()
      setmetatable(o, self)
      self.__index = self
      return o
end

function Variable:getID()
    return self.variableID    
end

function Variable:save()
    return {value = self.value}
end
function Variable:load(tbl)
    return self:new({value=tbl.value, callbacks = {}})
    
end
function Variable:loadUpdate(tbl,origins)
    return self:set(tbl.value,origins)
end

---@generic T
---@param value? T
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

function Variable:isInOrigins(origins)
    if type(origins) == "table" and origins[self:getID()] then
        return true
    else
        return false
    end
end

function Variable:stampCallbackOrigins(origins)
    if origins[self:getID()] then
        return
    end
    origins.n = (origins.n or 0) + 1
    origins[self:getID()] = origins.n
    return true
end

function Variable.stampOrigins(origins,id)
    if origins[id] then
        return false
    end
    origins.n = (origins.n or 0) + 1
    origins[id] = origins.n
    return true
    -- if origins[self:getID()] then
    --     return
    -- end
    -- origins.n = (origins.n or 0) + 1
    -- origins[self:getID()] = origins.n
    -- return true
end

function Variable.newOrigins(startID)
    if startID then
        return {startID=1,n=1}
    else
        return {}    
    end
end


---@generic T
---@param value T
---@param silent? CallbackOrigins|boolean
function Variable:set_(value,silent)
    -- if self.value == value then
    --     return
    -- end
    if self:isInOrigins(silent) then
        return
    end
    self.value = value
    self:updateCallbacks(silent)
end

function Variable:updateCallbacks(silent)
    if silent ~= true then
        silent = silent or {}
        silent.n = (silent.n or 0) + 1
        silent[self:getID()] = silent.n
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

---@generic Self
---@param self Self
---@param func fun(origins:CallbackOrigins,v: Variable)
---@return Self
function Variable:addSingleCallback(func)
    if not self.singleCallbacks then
        self.singleCallbacks = {i=0,n=0}
        self:addCallback(function (origins,v)
            while v.singleCallbacks.i < v.singleCallbacks.n do
                v.singleCallbacks.i = v.singleCallbacks.i + 1
                v.singleCallbacks[v.singleCallbacks.i](origins,v)
            end
        end)
    end
    self.singleCallbacks.n = self.singleCallbacks.n + 1
    self.singleCallbacks[self.singleCallbacks.n] = func
    
    return self
end


---@generic T, To
---@param self Variable[To]
---@param toMapped? fun(value:To):T
---@param toOriginal? fun(value:T):To
---@return BijectionVariable[T,To]
function Variable:bijection(toMapped,toOriginal)
    require "/okko.Variables.BijectionVariable" -- changes this function
    return self:bijection(toMapped,toOriginal)
end

-- makes self equal original. sets self to original immediately unless noupdate is set.
function Variable:equate(original,noupdate)
    require "/okko.Variables.BijectionVariable" -- changes this function
    return self:equate(original,noupdate)
end

Variable.isVariable = true

function Variable.getRealize(this)
    if type(this) == "table" and this.isVariable then
        return this:get()
    else
        return this
    end
end


return Variable