local thread = require "thread"
local os = require "os"
local Helper = require "Helper"
local serialization = require "serialization"

---@diagnostic disable thread
---@diagnostic disable os

---
---@generic T any
---@class Future<T>
---@field success boolean|nil -- true for success, false for error, nil for incomplete
---@field results table|nil -- result of pcall(func, ...)
---@field private t thread
---@field name? string
---@field parents? Future[]
---@field joined Future[]
local Future = {}

--- ephemeron table of threads to futures
--- @type table<thread,Future>
Future.list = setmetatable({}, {__mode = "k"})

Future.__index = Future

Future.DEBUG = false

--#region debugging

function Future:__tostring()
  if self.success == nil then
    return "Incomplete" .. self:formattedName() .. self:dependingString()
  elseif self.success == true then
    local out = {}
    for i = 2, #self.results do
      out[i - 1] = serialization.serialize(self.results[i], math.huge)
    end
    return "Success" .. self:formattedName() .. "(" .. table.concat(out, ", ") .. ")" .. self:dependingString()
  else --if self.success == false then
    return "Failure" .. self:formattedName() .. "(" .. tostring(self.results[2]) .. ")" .. self:dependingString()
  end
end

function Future:formattedName()
  return self.name and ("[" .. self.name .. "]") or ""
end

---returns a string of all parents
---empty string if no parents,
--- <-parent if 1 parent
--- <-{parent | parent} if multiple parents
---@return string
function Future:parentString()
  if not self.parents then
    return ""
  elseif #self.parents == 1 then
    return "<-" .. tostring(self.parents[1])
  else
    return "<-{" .. table.concat(Helper.map(self.parents, tostring), " | ") .. "}"
  end
end

function Future:joinedString()
  if self.joined[1] then
    return "{" .. table.concat(Helper.map(self.joined, tostring), " | ") .. "}"
  else
    return ""
  end
end

function Future:dependingString()
  return self:joinedString() .. self:parentString()
end

---sets the name of self, and returns self.
---@generic T Future
---@param self T
---@param name string
---@return T self
function Future:named(name)
  self.name = self.name and (name .. "|" .. self.name) or name -- todo: maybe new name goes before old names? that would be consistent with parents being after.
  return self
end

---for debugging, marks the future that this waits on.
---@generic T Future
---@param self T
---@param future Future
---@return T self
function Future:setParent(future)
  if Future.DEBUG then
    self.parents = {future} -- todo: also adds to the parent's children.
  end
  return self
end
---for debugging, marks the futures that this waits on.
---note: uses the table "futures" itself.
---@generic T Future
---@param self T
---@param futures Future[]
---@return T self
function Future:setParents(futures)
  if Future.DEBUG then
    self.parents = futures
  end
  return self
end

---marks the current
---@generic T Future
---@param self T
---@return T self
function Future:markJoin()
  if Future.DEBUG then
    local current = Future.current()
    if current then
      current.joined[#current.joined + 1] = self
    end
  end
  return self
end

---wraps arguments in a InstantFuture and calls markJoin with it. returns original arguments
---@generic T
---@vararg T
---@return T
function Future.markJoinInstant(...)
  Future.createInstant(true, ...):named("markJoin"):markJoin() -- todo: allow this name to change
  return ...
end

--#endregion debugging

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
  Future.list[fut.t] = fut
  fut.joined = {}
  return fut
end

--- blocks until completion, or timeout
---@param timeout? number seconds
---@return boolean|nil nil if timeout was reached, true otherwise.
function Future:join(timeout)
  return self.t:join(timeout) -- todo: should this mark self as a parent for currently running future. todo: how to access that
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
---@return Future|Future<boolean>
function Future:killAfter(timeout, success, ...)
  local args = {...}
  return self:onComplete(
    function()
      return self:kill(success, table.unpack(args))
    end,
    timeout
  ):named("killAfter"):setParent(self)
end

--- blocks until the future has completed, then returns success,result. returns nil if timed out
---@generic T any
---@param self Future<T>
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
---@return Future|Future<T2>
function Future:onComplete(func, timeout)
  return Future.create(
    function()
      return func(self:awaitProtected(timeout))
    end
  ):named("onComplete"):setParent(self)
end

--- eventually calls the function with this future's result if it succeeds
--- if self fails, the resulting future automatically fails, which may be sent to further onFailure
---@generic T2 any
---@generic T any
---@param self Future<T>
---@param func fun(...:T):T2? -- takes the result of self:
---@return Future|Future<T2>
function Future:onSuccess(func)
  return Future.create(
    function()
      self:join()
      if self.success then
        return func(table.unpack(self.results, 2))
      else
        error("failure- did not succeed") -- this will be caught by the pcall and sent to any further onFailure
      end
    end
  ):named("onSuccess"):setParent(self)
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
  ):named("onFailure"):setParent(self)
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
  ):named("promise")
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
  self:setParent(future)
end

--- a subclass of Future that instantly returns values without creating a thread
---@class InstantFuture: Future
local InstantFuture = setmetatable({}, Future)
InstantFuture.__index = InstantFuture
InstantFuture.__tostring = Future.__tostring

---creates a dummy future that instantly completes with args
---@generic T any
---@param success boolean
---@param ... T|string
---@return Future|Future<T>
function Future.createInstant(success, ...)
  local fut = setmetatable({}, InstantFuture)
  fut.results = {success, ...}
  fut.success = success
  fut.joined = {}
  -- since this does not wrap a function, adding it to Function.list is unnecessary and it doesn't have a key anyway
  return fut:named("instant")
end

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
---@return Future|Future<T>
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
  ):named("onAllComplete"):setParents(futures)
end

---combines futures into a single future that succeeds if all succeed, and fails if any fail or timeout.
---currently fails only once all have completed, not when any has failed
---@generic R any
---@param futures Future[]
---@param timeout? number seconds
---@return Future
function Future.combineAll(futures, timeout)
  return Future.onAllComplete(
    futures,
    function(resultses, success)
      if success then
        return resultses
      elseif success == false then
        error("failure. results: " .. table.concat(Helper.map(futures, tostring), " | "))
      else --if success == nil then
        error("timeout. results: " .. table.concat(Helper.map(futures, tostring), " | "))
      end
    end,
    timeout
  ):named("combineAll")
  --:setParents(futures) -- already done in onAllComplete
end

---gets currently executing Future, the one that calls this.
---may return nil, if not in a future, or if that future has been garbage collected.
---@return Future?
function Future.current()
  return Future.list[thread.current()]
end

-- todo: combineAll (and any derivative Future) shows the progress of the previous future

-- todo: thenReturn: future:thenReturn(foo) returns a Future that completes when future does and which return is foo

return Future
