
local Variable = require "/okko.Variables.Variable"
--- interesting, queued events send the object itself. surely this won't work with modems? - it wont. it wont work across programs either.

--- todo: a function that joins a variable tree into an existing tree.
--- then a base_type that 

local tArgs = table.pack(...)

local ExposedVariable = {}

---@class ExposedVariable: Variable
local ExposedVariable = Variable:new()

ExposedVariable.registered = {}
-- incomplete
function ExposedVariable:register(variable,id)
    if self.registered[id] then
        variable:equate(self.registered[id])
    else
        self.registered[id] = variable
        os.queueEvent()
    end
end
