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
---@field [1] fun(obj:T):R
---@field [2] (fun(obj:T):(number|nil)) | integer -- if integer, that means this is specifically for that index
---@field [3] Promise<R>

---@class PooledObject<T>
---@field busy boolean
---@field object T
---@field poolidentifier number
---@field index integer
---@field maintenance? fun(obj:T):boolean -- overload maintenance

--- used for limited resources that have to be reserved.
--- such as drones, or machines
---@generic T
---@class Pool<T>
---@field in_queue table<integer,PoolRequest> --- <T>
---@field objects PooledObject[] --- <T>
---@field poolidentifier number
---@field private t thread
---@field maintenance? fun(obj:T):boolean -- function periodically called on elements. blocks.
---@field maintenancePeriod? number -- seconds, how often to do maintenance
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
---@param maintenance? fun(obj:T):boolean
function Pool:register(object, maintenance)
    local i = #self.objects + 1
    self.objects[i] = {
        busy = false,
        object = object,
        poolidentifier = self.poolidentifier,
        index = i,
        maintenance = maintenance
    }
    self:_free(i)
end

---calls usage on an element of the pool eventually.
---the chosen element is the one that gets the minimum result from fitness, from all available elements,
---or if all elements are busy, the first element to eventually get freed up.
---@generic T
---@generic R
---@param usage fun(obj:T):R
---@param fitness (fun(obj:T):number|nil) | integer -- if integer, that means this is specifically meant for the object in that index
---@return Future|Future<R>
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
            self:_free(i)
        end
    )
    promise:completeWith(body)
end

function Pool:_free(i)
    event.push("Pool", self.poolidentifier, "freed", i)
end

function Pool:_do_queue(q)
    local usage, fitness, promise = table.unpack(self.in_queue[q]) --- Drones.queue
    ---@cast usage    fun(obj:R):R
    ---@cast fitness  fun(obj:T):(number|nil)
    ---@cast promise  Promise<R>

    local fittestIndex = nil
    if type(fitness) == "number" then
        if self.objects[fitness] and not self.objects[fitness].busy then
            fittestIndex = fitness
        end
    else
        _, fittestIndex =
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
    end
    if fittestIndex then
        self.in_queue[q] = nil
        self:_call(usage, promise, fittestIndex)
        return true
    else
        return false
    end
end
function Pool:_do_freed(i)
    local obj = self.objects[i]
    for k, v in pairs(self.in_queue) do
        local usage, fitness, promise = table.unpack(v)
        ---@cast usage    fun(obj:R):R
        ---@cast fitness  fun(obj:T):(number|nil)
        ---@cast promise  Promise<R>
        local success, fit
        if type(fitness) == "number" then
            if i == fitness then
                success = true
                fit = 0
            else
                success = true
                fit = nil
            end
        else
            success, fit = pcall(fitness, obj.object)
        end
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
        elseif pulled[3] == "maintenance" then
            self:_maintain()
        end
    end
end

---if you think the pool has gone out of sync, try calling this
---@return boolean worked -- did this do anything
---@return integer hits -- how many times did this work
function Pool:jostleQueue()
    local hits = 0
    for key, _ in pairs(self.in_queue) do
        if self:_do_queue(key) then
            hits = hits + 1
        end
    end
    return hits ~= 0, hits
end

--- todo: maintenance should be buffered, not all at once, so only part of the objects become busy
function Pool:_maintain()
    for index, _ in pairs(self.objects) do
        self:_maintain_obj(index)
    end
end

function Pool:_maintain_obj(i)
    local maintenance = self.objects[i].maintenance or self.maintenance
    if maintenance then
        self:queue(maintenance, i)
    end
end

---sets a maintenance function to all objects
---@param maintenance fun(obj:T):boolean
function Pool:setMaintenance(maintenance)
    self.maintenance = maintenance
end

---set how often maintenance is done. nil to stop periodic maintenance.
---@param seconds number|nil
function Pool:setMaintenancePeriod(seconds)
    self.maintenancePeriod = seconds
    if self._maintenance_timerID then
        event.cancel(self._maintenance_timerID)
        self._maintenance_timerID = nil
    end
    if seconds then
        self._maintenance_timerID =
            event.timer(
            seconds,
            function()
                event.push("Pool", self.poolidentifier, "maintenance")
            end,
            math.huge
        )
    end
end

return Pool
