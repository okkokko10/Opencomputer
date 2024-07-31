---@diagnostic disable: undefined-doc-name
local Future = require "Future"
local event = require "event"
local thread = require "thread"
local Helper = require "Helper"

-- todo: it could be more efficient to wait a second instead of immediately starting a request, so that objects that fit better can be chosen.

-- todo: what if one machine can do multiple things, can it be in multiple pools?

-- todo: FIFO

---@generic T any
---@generic R any
---@class PoolRequest<T>
---@field [1] fun(obj:"T"):"R"
---@field [2] fun(obj:"T"):(number|nil)
---@field [3] Promise<"R">

---@class PooledObject<T>
---@field busy boolean
---@field object T
---@field poolidentifier number
---@field index integer

--- used for limited resources that have to be reserved.
--- such as drones, or machines
---@generic T
---@class Pool<T>
---@field in_queue PoolRequest[] --- <T>
---@field objects PooledObject[] --- <T>
---@field poolidentifier number
---@field private t thread
local Pool = {}

Pool.__index = Pool

function Pool.create()
    local pool = setmetatable({in_queue = {}, objects = {}, poolidentifier = math.random()}, Pool)
    pool.t = pool:_main_thread()
    return pool
end

function Pool:_main_thread()
    return thread.create(self._main, self)
end

---adds the object to this pool
---@generic T
---@param self Pool ---<T>
---@param object T
function Pool:register(object)
    local i = #self.objects + 1
    self.objects[i] = {
        busy = false,
        object = object,
        poolidentifier = self.poolidentifier,
        index = i
    }
end

---comment
---@generic T
---@generic R
---@param usage fun(obj:T):R
---@param fitness fun(obj:T):number|nil
---@return Future<R>
function Pool:queue(usage, fitness)
    local finish_promise = Future.createPromise()
    local q = #self.in_queue + 1
    table.insert(self.in_queue, q, {usage, fitness, finish_promise})
    event.push("Pool", self.poolidentifier, "queue", q)
    return finish_promise
end

function Pool:_call(usage, promise, i)
    self.objects[i].busy = true
    local body =
        Future.create(
        function()
            return usage(self.objects[i].object)
        end
    )
    body:onComplete(
        function()
            event.push("Pool", self.poolidentifier, "freed", i)
        end
    )
    promise:completeWith(body)
end

function Pool:_do_queue(q)
    local usage, fitness, promise = table.unpack(self.in_queue[q]) --- Drones.queue
    ---@cast usage    fun(obj:R):R
    ---@cast fitness  fun(obj:T):(number|nil)
    ---@cast promise  Promise<R>

    local fittestObj, fittestIndex =
        Helper.min(
        self.objects,
        ---@param v PooledObject
        ---@param i integer
        function(v, i)
            if v.busy then
                return nil
            else
                local success, fit = pcall(fitness, v.object)
                if not success then
                    event.onError("error in fitness: " .. fit)
                    return nil
                else
                    return fit
                end
            end
        end
    )
    if fittestIndex then
        self.in_queue[q] = nil
        self:_call(usage, promise, fittestIndex)
    end
end
function Pool:_do_freed(i)
    local obj = self.objects[i]
    for k, v in pairs(self.in_queue) do
        local usage, fitness, promise = table.unpack(v)
        ---@cast usage    fun(obj:R):R
        ---@cast fitness  fun(obj:T):(number|nil)
        ---@cast promise  Promise<R>
        local success, fit = pcall(fitness, obj.object)
        if not success then
            event.onError("error in fitness: " .. fit)
        elseif fit and fit < math.huge then -- todo: have there also be a competition about fitness here, so if there is a lot of work piled up, the closest gets done first
            self.in_queue[k] = nil
            self:_call(usage, promise, i)
            return
        end
    end
    obj.busy = false
end

function Pool:_main()
    while true do
        local pulled = {event.pull("Pool", self.poolidentifier)}
        if pulled[3] == "freed" then
            local i = pulled[4]
            local success, result = pcall(self._do_freed, self, i)
            if not success then
                event.onError("error in freed: " .. result)
            end
        elseif pulled[3] == "queue" then
            local q = pulled[4]
            local success, result = pcall(self._do_queue, self, q)
            if not success then
                event.onError("error in queue: " .. result)
            end
        end
    end
end

return Pool
