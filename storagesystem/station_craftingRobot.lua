local longmsg_message = require "longmsg_message"
local component = require "component"

component.robot.select(13)

---comment
---@param longmessage LongMessage
local function listener(longmessage)
    if longmessage.name == "craft_command" then
        local yes, amount = component.crafting.craft()
        print(amount)
        longmsg_message.sendmessage("craft_complete", tostring(amount), nil, nil)
    end
end

longmsg_message.listenTable(listener)
