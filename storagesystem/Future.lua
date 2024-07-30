local thread = require "thread"
local os = require "os"


---@diagnostic disable thread
---@diagnostic disable os

---
---@generic T any
---@class Future<T>
---@field success boolean|nil -- true for success, false for error, nil for incomplete
---@field results table -- result of pcall(func, ...)
---@field private t thread
local Future = {}

Future.__index = Future

--- creates a new future.
---@generic T any
---@param func fun():T
---@return Future<T>
function Future.create(func)
  local fut = setmetatable({}, Future)
  fut.t = thread.create(function()
    local results = {pcall(func)}
    fut.results = fut.results or results -- could alleviate race conditions from kill?
    fut.success = results[1]
  end)
  return fut
end



--- blocks until completion, or timeout
---@param timeout? number seconds
---@return boolean|nil nil if timeout was reached, true otherwise.
function Future:join(timeout)
  return self.t:join(timeout)
end

--- if incomplete, kills the future's execution, 
--- if provided, sets the result of the future to the arguments
--- otherwise makes it a failure with error message "kill".
---@generic T
---@param success? boolean
---@vararg T|string|nil
---@return boolean whether this killed the future
function Future:kill(success, ...)
  if not self.results then -- todo: is this a race condition?
    if success ~= nil then
      self.results = {success, ...}
      self.success = success
    else
      self.results = {false, "kill"}
      self.success = false
    end
    self.t:kill()
    return true
  else
    return false
  end
end

--- side-effect: kills this future with Future:kill(success, ...) after timeout seconds. returns a new future that returns true if the timeout killed the future
---@generic T
---@param timeout number seconds
---@param success? boolean
---@vararg T|string|nil
---@return Future<boolean> 
function Future:killAfter(timeout, success, ...)
  local args = {...}
  return self:onComplete(function()
    return self:kill(success, table.unpack(args))
  end, timeout)
end

--- blocks until the future has completed, then returns success,result. returns nil if timed out
---@generic T any
---@param timeout? number seconds
---@return boolean|nil,T|nil
function Future:awaitProtected(timeout)
  if self:join(timeout) then
    return table.unpack(self.results)
  else
    return nil
  end
end

--- blocks until the future has completed, then returns result. propagates its errors and throws an error if timed out
---@generic T
---@param timeout? number seconds -- throws error("timeout") if not met
---@return T
function Future:awaitResult(timeout)
  if self:join(timeout) then
    if self.success then
      return table.unpack(self.results, 2)
    else
      error(self.results[2], 2)
    end
  else
    error("timeout", 2)
  end
end

--- eventually calls the function with this future's success and result
---@generic T2 any
---@generic T any
---@param func fun(success:boolean|nil,...:T):T2 -- takes the result of self:awaitProtected(timeout) as input
---@param timeout? number seconds -- starting from when this is registered
---@return Future<T2>
function Future:onComplete(func, timeout)
  return Future.create(function()
    return func(self:awaitProtected(timeout))
  end)
end

--- eventually calls the function with this future's result if it succeeds
--- if self fails, the resulting future automatically fails, which may be sent to further onFailure
---@generic T2 any
---@generic T any
---@param func fun(...:T):T2 -- takes the result of self:
---@return Future<T2>
function Future:onSuccess(func)
  return Future.create(function()
    self:join()
    if self.success then
      return func(table.unpack(self.results, 2))
    else
      error("failure") -- this will be caught by the pcall and sent to any further onFailure
    end
  end)
end

--- eventually calls the function with this future's error if it fails
--- if self succeeds, the resulting future automatically fails, which may be sent to further onFailure
---@generic T2 any
---@param func fun(errormessage:string):T2
---@return Future<T2>
function Future:onFailure(func)
  return Future.create(function()
    self:join()
    if self.success then
      error("success") -- this will be caught by the pcall and sent to any further onFailure
    else
      return func(table.unpack(self.results, 2))
    end
  end)
end

---
--
--

--- a future that never succeeds on its own (unless timeout)
--- use fulfilPromise to fulfil it
---@param timeout? number seconds
function Future.createPromise(timeout)
  return Future.create(function()
    os.sleep(timeout or math.huge)
    error("promise timed out")
  end)
end

--- meant for promises, makes it a success and sets the result to arguments
---@vararg any
---@return boolean if this is what completed the promise
function Future:fulfilPromise(...)
  return self:kill(true, ...)
end

--- meant for promises, makes it a failure and sets the error message
---@param errormessage string
---@return boolean -- if this is what completed the promise
function Future:failPromise(errormessage)
  checkArg(1, errormessage, "string")
  return self:kill(false, errormessage)
end

--- meant for promises, sets outcome like pcall results. alias for Future:kill
---@param success boolean
---@vararg any
---@return boolean -- if this is what completed the promise
function Future:completePromise(success, ...)
  checkArg(1, success, "boolean")
  return self:kill(success, ...)
end

return Future
