local BaseElement = require "BaseElement"

print("imported BaseElement")
local RootElement = require "RootElement"

print("imported RootElement")
local MyVariableRect = require "MyVariableRect"
print("imported MyVariableRect")


local root = RootElement:create(term.current())
print("created root")

root:addChild(MyVariableRect)
print("added child")

root:rec_render()
print("finished")

while true do
    local event, misc, x, y = os.pullEvent("mouse_drag")
    -- print(misc,x,y)
    root:mouseEventRaw(event,misc,x,y)
    term.clear()
    root:rec_render()

end