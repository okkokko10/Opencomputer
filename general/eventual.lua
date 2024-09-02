---@class EventualValue: any
---@field _propagators? table
---@field _propagate? table

local eventual = {}

---checks immediately whether x is an eventual value
---@param x EventualValue|any?
---@return boolean
function eventual.isEventual(x)
    if type(x) == "table" then
        return true -- todo: stub
    else
        return false
    end
end

---if condition then Then else Else.
---note: if Then or Else aren't eventual, they will be evaluated immediately.
---@generic T, E
---@param condition EventualValue|any
---@param Then EventualValue|T
---@param Else EventualValue|E?
---@return T|E|EventualValue?
function eventual.choose(condition, Then, Else)
    if condition then
        return Then
    else
        return Else
    end -- todo: this should return a new eventual
end

---@param a EventualValue|any?
---@param b EventualValue|any?
---@return EventualValue|boolean
function eventual.eq(a, b)
    return a == b
end

---@param x EventualValue|any?
---@return EventualValue|boolean
function eventual.negate(x)
    return not x
end

---@param a EventualValue|any?
---@param b EventualValue|any?
---@return EventualValue|boolean
function eventual.neq(a, b)
    return eventual.negate(eventual.eq(a, b))
end

function eventual.assert(v, message)
    return {
        _act = function()
            assert(eventual.evaluate(v), message)
        end
    }
end

eventual.nests = {}

---whether this wasn't skipped with IF
---@return boolean|EventualValue
function eventual.notSkipped()
    return eventual.nests[#eventual.nests] or #eventual.nests == 0
end

---until `eventual.END` (or `eventual.ELSE`) is called, if x is false, eventual instructions will be ignored.
---
---@param x any
function eventual.IF(x)
    eventual.nests[#eventual.nests + 1] = eventual.AND(eventual.notSkipped(), x)
end
function eventual.ELSE()
    assert(#eventual.nests > 0)
    eventual.nests[#eventual.nests] =
        eventual.AND(
        eventual.nests[#eventual.nests - 1] or (#eventual.nests == 1),
        eventual.negate(eventual.notSkipped())
    )
end

function eventual.END()
    eventual.nests[#eventual.nests] = nil
end

---call func once all values of after are evaluated, and only if the portion is not skipped by IF.
---@generic R
---@param func fun():R?
---@param after (EventualValue|any)[]
---@return R|EventualValue
function eventual.DO(func, after)
    if eventual.evaluate(eventual.nests) then
        return func() -- todo
    else
        return nil
    end
end

---links target to the rest of the args, updating it when they are updated.
---@param target EventualValue|any
---@param ... EventualValue|any
function eventual.link(target, ...)
    if eventual.isEventual(target) then
        target._propagators = {...}
        for i, value in ipairs(target._propagators) do
            if eventual.isEventual(value) then
                local _propagate = value._propagate
                if not _propagate then
                    _propagate = {}
                    value._propagate = _propagate
                end
                table.insert(_propagate, target)
            end
        end
    end
    return target
end

--- todo:
---if in a non-executing path, returns an object that accepts any method call.
---if it can execute, looks at all direct and 1-deep EventualValues and postpones execution until they finish.
---@generic T
---@param obj T
---@return T
function eventual.wrap(obj)
    return setmetatable(
        {_hollow_obj = obj, _hollow_notSkipped = eventual.notSkipped()},
        {
            __index = function(t, k)
                return function(...)
                    return eventual.link({t = t, funcname = k, params = {...}}, t._hollow_notSkipped, ...)
                end
            end
        }
    )
end

function eventual.AND(a, b)
    return a and b -- todo
end

function eventual.evaluate(x)
    return x -- todo
end

return eventual
