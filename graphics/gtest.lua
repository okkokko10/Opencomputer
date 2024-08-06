local GraphicsDraw = require "graphics.GraphicsDraw"
local GraphicsRect = require "graphics.GraphicsRect"
local Slider = require "graphics.Slider"
local event = require "event"
local Transform2D = require "graphics.Transform2D"

local rx, ry = GraphicsDraw.gpu_data.gpu.getResolution()

local draw = GraphicsDraw:create(Transform2D.Identity, rx + 1, ry + 1, 0)

local slider_pattern_data = {
    checker_interval = 8,
    fillchar = ":",
    point_fore = 0xFFFFFF,
    point_back = 0xFF8000,
    left_fore_A = 0xFFFFFF,
    left_back_A = 0x444444,
    left_fore_B = 0xFFFFFF,
    left_back_B = 0x999999,
    right_fore_A = 0xFFFFFF,
    right_back_A = 0x449944,
    right_fore_B = 0xFFFFFF,
    right_back_B = 0x994499
} -- old color data

local slider =
    Slider:create(
    Transform2D:Move(5, 5),
    64,
    "¤value=",
    "¤0x0000FF-::::::::¤0xFF0000-||||",
    "¤0x00FF00-........¤0x800000-****"
)

local main_rect = GraphicsRect:create(Transform2D.Identity, rx, ry, {slider})

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
