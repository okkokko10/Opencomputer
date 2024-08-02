local GraphicsDraw = require "graphics.GraphicsDraw"
local GraphicsRect = require "graphics.GraphicsRect"
local Slider = require "graphics.Slider"
local event = require "event"

local rx, ry = GraphicsDraw.gpu_data.gpu.getResolution()

local draw = GraphicsDraw:create(0, 0, rx + 1, ry + 1, 0)

local slider = Slider:create(5, 5, 64, 8, false, nil, nil, nil, ":")

local main_rect = GraphicsRect:create(1, 1, rx, ry, {slider})

local tou =
    event.listen(
    "touch",
    function(_, screenAddress, x, y, button, playerName)
        main_rect:_onClick(x, y, button, playerName)
    end
)

local tim =
    event.timer(
    0.1,
    function()
        main_rect:_draw(draw, true)
    end,
    math.huge
)

local en
en =
    event.listen(
    "touch",
    function(_, screenAddress, x, y, button, playerName)
        if x == 1 and y == 1 then
            event.cancel(en)
            event.cancel(tou)
            event.cancel(tim)
        end
    end
)

return slider
