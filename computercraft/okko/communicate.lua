
local hb = require "helpblit"
local md = peripheral.find("modem") or error("No modem attached", 0)

local params = {...}

local PORT = tonumber(params[2]) or 1
local username = params[1] or "abc"

local knownUsers = {}

md.open(PORT)

local function listener_debug()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        print(("Message received on side %s on channel %d (reply to %d) from %f blocks away with message %s"):format(
            side, channel, replyChannel, distance, tostring(message)
        ))
    end
end

local sx, sy = term.getSize()
local input_y = sy-6
local win_conversation = window.create(term.current(),1,1,sx,input_y-1)
win_conversation.setBackgroundColor(12)
local win_input = window.create(term.current(),1,input_y,sx,sy-input_y)
win_input.setBackgroundColor(7)



local function addMessage(info,message)

    term.redirect(win_conversation)
    term.current().restoreCursor()
    term.current().redraw()
    hb.blitHet(info, "2")
    hb.blitHet(": ", "0")
    hb.blitHet(tostring(message) .. "\n")
    print()
    term.redirect(win_input)
    term.current().restoreCursor()
    term.current().redraw()


end


local function listener()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        local info = ("%d<-%d (%fm)"):format(
            channel, replyChannel, distance
        )
        addMessage(info,tostring(message))
    end
end

local function user()
    
    term.redirect(win_input)
    win_input.setCursorPos(1,1)
    while true do
        local w = read()
        addMessage("[YOU]",w)
        md.transmit(PORT,PORT,w)
        win_input.clear()
        win_input.setCursorPos(1,1)
    end
end

local function main()
    parallel.waitForAny(listener,user)

end

main()