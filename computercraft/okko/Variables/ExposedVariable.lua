
local Variable = require "/okko.Variables.Variable"
--- interesting, queued events send the object itself. surely this won't work with modems? - it wont. it wont work across programs either.

--- todo: a function that joins a variable tree into an existing tree.
--- then a base_type that 
--- 


--- a host process, and in parallel the code and a client.
--- 

local tArgs = table.pack(...)

local ExposedVariable = {}

---@class ExposedVariable: Variable
local ExposedVariable = {}

ExposedVariable.registered = {}


ExposedVariable.recipients = {12,13,14}

-- ExposedVariable.saves = {}

ExposedVariable.progID = math.random()


function ExposedVariable:updateCallback(id,variable,origins)
    if Variable.stampOrigins(origins,id) then
        os.queueEvent("ExposedVariable",{eType = "set",id = id,value = variable:get(),origins = origins})
    end
    
end

---comment
---@param id string
---@param variable Variable
function ExposedVariable:addUpdateCallback(id,variable)
    variable:addCallback(function (origins, v)
        self:updateCallback(id,v,origins)
    end)
end


ExposedVariable.rednet = false
function ExposedVariable:activatePublic()
    if not self.rednet then
        self.rednet = true
        peripheral.find("modem", rednet.open)
    end
end

-- sets the exposed variable to this value if it already exists
function ExposedVariable:register(id,variable,public)
    variable = variable or Variable:create(nil)

    if public then
        self.isPublic[id] = true
        self:activatePublic()
    end
    if self.registered[id] then
        self.registered[id]:equate(variable)
    else
        self.registered[id] = variable
        self.isReady[id] = true
        self:addUpdateCallback(id,variable)
        self:updateCallback(id,variable,Variable.newOrigins(variable:getID()))
        -- os.queueEvent("ExposedVariable_register",id,variable:save())
    end
    return variable
end

-- waits until a process responds. incomplete
-- function ExposedVariable:query(id,super)
--     os.queueEvent("ExposedVariable_query",id)
--     local event, id2, save = os.pullEvent("ExposedVariable_query_response")
--     ;(super or Variable):load(save)
-- end


--- links variable to id, and waits until a response sets it.
---@generic T
---@param id any
---@param variable T
---@param wait? boolean
---@return T
function ExposedVariable:link(id,variable,wait,public)
    variable = variable or Variable:create(nil)
    if public then
        self.isPublic[id] = true
        self:activatePublic()
    end
    if self.registered[id] then
        variable:equate(self.registered[id])
        return variable
    else
        self.registered[id] = variable
        self:addUpdateCallback(id,variable)
        self.isReady[id] = false
        os.queueEvent("ExposedVariable",{eType="get", id=id})
        while wait do
            local event, id2,self2 = os.pullEvent("ExposedVariable_set_done");
            if id2 == id and self2==self.progID then
                return variable
            end
        end
        return variable
    end
end

ExposedVariable.isReady = {}
ExposedVariable.isPublic = {}


-- ExposedVariable.hosted = {}
-- function ExposedVariable:sendAll()
--     local tbl = {}
--     for key, value in pairs(self.hosted) do
--         tbl[key] = value:save()
--     end
--     os.queueEvent("ExposedVariable_all",tbl)
-- end

-- idea: origins tracks the parent. also make it a stack.


function ExposedVariable:receive1(addnew)
    local event, tbl, fromRednet = os.pullEvent("ExposedVariable")
    if ( not fromRednet ) and self.isPublic[tbl.id] then
        for key, value in pairs(self.recipients) do
            local success = rednet.send(value,tbl,"ExposedVariable_public")
            if not success then
                local pretty = (require "cc.pretty")
                error("failed to send " .. pretty.render(pretty.pretty(tbl)))
            end
        end
    end
    -- if ( fromRednet ) and (not self.isPublic[tbl.id]) and (not addnew) then 
    --     return
    -- end
    


    if tbl.eType == "set" then
        if self.registered[tbl.id] then
                self.registered[tbl.id]:set(tbl.value,tbl.origins)
                os.queueEvent("ExposedVariable_set_done",tbl.id,self.progID)
        else
            if addnew then
                local variable = Variable:create(tbl.value)
                self.registered[tbl.id] = variable
                self:addUpdateCallback(tbl.id,variable)
            end
        end
    end
    if tbl.eType == "get" then
        if self.registered[tbl.id] and self.isReady[tbl.id] then
            self:updateCallback(tbl.id,self.registered[tbl.id],Variable.newOrigins(self.registered[tbl.id]:getID()))
        end
    end
end

function ExposedVariable.receive_rednet()
    while true do
        local sender, message = rednet.receive("ExposedVariable_public")
        if ExposedVariable.isPublic[message.id] then
            os.queueEvent("ExposedVariable",message,true)
        end
    end
end

-- function ExposedVariable:receive()
--     local event, tbl = os.pullEvent("ExposedVariable_all")
--     for key, value in pairs(tbl) do
--         self.saves[key] = value
--         if self.registered[key] then
--             self.registered[key]:loadUpdate(value)
--         end
--     end
-- end

--- you must call this in parallel with the program you want to use variables in
function ExposedVariable.run()
    while true do
        ExposedVariable:receive1()
    end
end
function ExposedVariable:wrap(func)
    parallel.waitForAny(self.run,self.receive_rednet,func)
end


-- function ExposedVariable:host()
--     while true do
--         local tEvent = table.pack(os.pullEventRaw())
--     end
-- end

function ExposedVariable:display(te)
    te.clear()
    local x = 1
    local y = 1
    te.setCursorPos(x,y)

    te.write("displaying exposed variables")
    y = y + 1
    te.setCursorPos(x,y)
    te.write("----------------------------")
    y = y + 1
    for key, value in pairs(self.registered) do
        te.setCursorPos(x,y)
        te.write(tostring(key).. ": " .. tostring(value.value))
        y = y + 1
    end
end


function ExposedVariable:run_display(addnew)
    local te = term.current()
    parallel.waitForAny(
    self.receive_rednet,
    function ()
        while true do
            self:receive1(addnew)
        end
    end,
    function ()
        while true do
            self:display(te)
            os.sleep(0.1)
        end
    end
    )
end

if tArgs[1] == "display" then
    ExposedVariable:run_display(true)
end

return ExposedVariable