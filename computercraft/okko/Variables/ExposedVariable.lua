
local Variable = require "/okko.Variables.Variable"
--- interesting, queued events send the object itself. surely this won't work with modems? - it wont. it wont work across programs either.

--- todo: a function that joins a variable tree into an existing tree.
--- then a base_type that 
--- 


--- a host process, and in parallel the code and a client.
--- 

local tArgs = table.pack(...)

local ExposedVariable = {}


ExposedVariable.registered = {}


ExposedVariable.recipients = {12,13,14}

-- ExposedVariable.saves = {}

ExposedVariable.progID = math.random()

ExposedVariable.metatables = {
    quaternion = function (value)
        return quaternion.fromComponents(value.v.x,value.v.y,value.v.z,value.a)
    end,
    vector = function (value)
        return vector.new(value.x,value.y,value.z)
    end,
    matrix = matrix.from2DArray
}

function ExposedVariable.pack_metatable(value)
    if type(value) == "table" then
        return {value,getmetatable(value) and getmetatable(value).__name}
    else
        return value
    end
end
function ExposedVariable.unpack_metatable(value)
    if type(value) == "table" then
        os.queueEvent("debug unpack",value)
        local f = ExposedVariable.metatables[value[2]]
        if type(f) == "table" then
            return setmetatable(value[1],f)
        elseif type(f) == "function" then
            return f(value[1])
        else
            return value[1]
        end
    else
        return value
    end
    return value[1]
end

function ExposedVariable:updateCallback(id,variable,origins)
    if Variable.stampOrigins(origins,id) then
        os.queueEvent("ExposedVariable",{eType = "set",id = id,value = ExposedVariable.pack_metatable(variable:get()),origins = origins})
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

ExposedVariable.list = {}

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
        self.list[#self.list+1] = id
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
        self.list[#self.list+1] = id
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
                self.registered[tbl.id]:set(self.unpack_metatable(tbl.value),tbl.origins)
                os.queueEvent("ExposedVariable_set_done",tbl.id,self.progID)
        else
            if addnew then
                local variable = Variable:create(self.unpack_metatable(tbl.value))
                self.registered[tbl.id] = variable
                self:addUpdateCallback(tbl.id,variable)
                self.list[#self.list+1] = tbl.id

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
    parallel.waitForAny(self.run,self.receive_rednet,function ()
       if func() then
            while true do
                sleep(100)
            end
       end 
    end)
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
    for i, key in pairs(self.list) do
        te.setCursorPos(x,y)
        te.write(tostring(key).. ": " .. tostring(self.registered[key].value))
        y = y + 1
    end
end
local completion = require "cc.completion"
function ExposedVariable.input(win_input)

    term.redirect(win_input)
    win_input.setCursorPos(1,1)
    local history = {}
    local function completeFn(partial)
        local w = string.match(partial,"^(%S*)%s* $")
        if w then
            if ExposedVariable.registered[w] then
                return {
                    tostring(ExposedVariable.registered[w]:get())
                }
            else
                return {}
            end
        end
        return completion.choice(partial,ExposedVariable.list)
        
        -- local out = {}
        -- for index, value in ipairs(ExposedVariable.list) do
        --     if string.find(value,partial) then
        --         out[#out+1] = value .. " "
        --     end
        -- end
        -- return out
    end
    while true do
        local w = read(nil,history,completeFn)
        history[#history+1] = w
        
        local id, valuestring = string.match(w,"^(%S*)%s*(.*)%s*$")
        local func = load("return ".. valuestring)
        local success, value
        if func then
            success, value =  pcall(func)
        end
        os.queueEvent("debug",tostring(func),success,value)

        if success then
            os.queueEvent("ExposedVariable",{eType = "set",id = id,
                value = ExposedVariable.pack_metatable(value),origins = {}})
        end
        win_input.clear()
        win_input.setCursorPos(1,1)
    end
    
end

function ExposedVariable:run_display(addnew)
    local te = term.current()
    local w,h = term.getSize()
    local heig = 5
    local win_te = window.create(te,1,1,w,h-heig-1)

    local win_input = window.create(te,1,h-heig,w,heig)
    win_input.setBackgroundColor(7)

    parallel.waitForAny(
    self.receive_rednet,
    function ()
        while true do
            self:receive1(addnew)
        end
    end,
    function ()
        while true do
            self:display(win_te)
            win_input.restoreCursor()
            os.sleep(0.1)
        end
    end,
    
    function ()
        ExposedVariable.input(win_input)
    end
    )
end

if tArgs[1] == "display" then
    ExposedVariable:run_display(true)
end

return ExposedVariable