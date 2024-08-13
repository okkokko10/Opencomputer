local thread = require "thread"
local os = require "os"
local Helper = require "Helper"

---@diagnostic disable thread
---@diagnostic disable os

---
---@generic T any
---@class Future<T>
---@field success boolean|nil -- true for success, false for error, nil for incomplete
---@field results table|nil -- result of pcall(func, ...)
---@field private t thread
local Future = {}

Future.__index = Future

function Future:__tostring()
  if self.success == nil then
    return "Incomplete"
  elseif self.success == true then
    local out = {}
    for i = 2, #self.results do
      out[i - 1] = tostring(self.results[i])
    end
    return "Success(" .. table.concat(out, ", ") .. ")"
  end
  return "Failure(" .. tostring(self.results[2]) .. ")"
end

--- creates a new future.
---@generic T any
---@param func fun():T?
---@return Future
function Future.create(func)
  local fut = setmetatable({}, Future)
  fut.t =
    thread.create(
    function()
      local results = {pcall(func)}
      fut.results = fut.results or results -- could alleviate race conditions from kill?
      fut.success = results[1]
    end
  )
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
  return self:onComplete(
    function()
      return self:kill(success, table.unpack(args))
    end,
    timeout
  )
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
---@param func fun(success:boolean|nil,...:T):T2? -- takes the result of self:awaitProtected(timeout) as input
---@param timeout? number seconds -- starting from when this is registered
---@return Future<T2>
function Future:onComplete(func, timeout)
  return Future.create(
    function()
      return func(self:awaitProtected(timeout))
    end
  )
end

--- eventually calls the function with this future's result if it succeeds
--- if self fails, the resulting future automatically fails, which may be sent to further onFailure
---@generic T2 any
---@generic T any
---@param self Future<T>
---@param func fun(...:T):T2? -- takes the result of self:
---@return Future<T2>
function Future:onSuccess(func)
  return Future.create(
    function()
      self:join()
      if self.success then
        return func(table.unpack(self.results, 2))
      else
        error("failure") -- this will be caught by the pcall and sent to any further onFailure
      end
    end
  )
end

--- eventually calls the function with this future's error if it fails
--- if self succeeds, the resulting future automatically fails, which may be sent to further onFailure
---@generic T2 any
---@param func fun(errormessage:string):T2?
---@return Future<T2>
function Future:onFailure(func)
  return Future.create(
    function()
      self:join()
      if self.success then
        error("success") -- this will be caught by the pcall and sent to any further onFailure
      else
        return func(table.unpack(self.results, 2))
      end
    end
  )
end

---
--
---@alias Promise Future

--- a future that never succeeds on its own (unless timeout)
--- use fulfilPromise to fulfil it
---@param timeout? number seconds
---@return Promise
function Future.createPromise(timeout)
  return Future.create(
    function()
      os.sleep(timeout or math.huge)
      error("promise timed out")
    end
  )
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

--- sets the promise to copy this future
---@param future Future
function Future:completeWith(future)
  future:onComplete(
    function(success, ...)
      return self:completePromise(success, ...)
    end
  )
end

---creates a dummy future that instantly completes with args
---@generic T any
---@param success boolean
---@param ... T|string
---@return Future<T>
function Future.createInstant(success, ...)
  local fut = setmetatable({}, InstantFuture)
  fut.results = {success, ...}
  fut.success = success
  return fut
end

--- a subclass of Future that instantly returns values without creating a thread
---@class InstantFuture: Future
local InstantFuture = setmetatable({}, Future)
InstantFuture.__index = InstantFuture

function InstantFuture:kill(...)
  return false
end
function InstantFuture:join(...)
  return true
end

---takes all threads from the futures
---remember that not all futures have threads
---@param futures Future[]
---@return thread[]
local function filtermapToThreads(futures)
  return Helper.mapIndexed(
    futures,
    function(fut, k)
      return fut.t
    end
  )
end

--- blocks until all futures are complete
---@param futures Future[]
---@param timeout? number seconds
---@return boolean not_timed_out
function Future.joinAll(futures, timeout)
  local threads = filtermapToThreads(futures)
  return thread.waitForAll(threads, timeout)
end

---@deprecated todo
-- waits for any of the futures to succeed. returns nil if timeout or all futures fail
function Future.awaitAnySuccess(futures, timeout)
end

--- executes func when all are complete
---@generic T
---@param futures Future[]
---@param func fun(resultses:table[],success:boolean|nil):T -- success: nil if timed out, true if all succeed, false if some fail
---@param timeout any
---@return Future<T>
function Future.onAllComplete(futures, func, timeout)
  return Future.create(
    function()
      local success = Future.joinAll(futures, timeout) or nil
      local resultses =
        Helper.map(
        futures,
        function(fut, key)
          success = success and fut.success
          return fut.results
        end
      )
      return func(resultses, success)
    end
  )
end

---combines futures into a single future that succeeds if all succeed, and fails if any fail or timeout.
---currently fails only once all have completed, not when any has failed
---@generic R any
---@param futures Future[]
---@param timeout? number seconds
---@param thenReturn? R
---@return Future<R>
function Future.combineAll(futures, timeout, thenReturn)
  return Future.onAllComplete(
    futures,
    function(resultses, success)
      if success == false then
        error("failure")
      elseif success == nil then
        error("timeout")
      end
      return thenReturn
    end,
    timeout
  )
end

-- todo: thenReturn: future:thenReturn(foo) returns a Future that completes when future does and which return is foo

return Future
