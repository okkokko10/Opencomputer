local component = require "component"
local modem = component.modem
modem.open(1)
print(modem.broadcast(1,...))