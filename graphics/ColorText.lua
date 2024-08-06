local Helper = require "Helper"

---@alias Color integer

---@alias ColorTextPattern string

---@class ColorTextStrip
---@field text string
---@field fg Color|nil
---@field bg Color|nil
---@field length integer
---@field column integer -- how much is the text offset to the right. can be negative
---@field row integer
---@field anchor? [integer,integer]

local ColorText = {}

ColorText.gmatch_prefix = "¤"

ColorText.gmatch_textmatch = "(.-)%f[" .. ColorText.gmatch_prefix .. "\0]"

ColorText.gmatch_specials = "[:%-<>!=]"

ColorText.gmatch_pattern =
    ColorText.gmatch_prefix .. "(.-)(" .. ColorText.gmatch_specials .. ")" .. ColorText.gmatch_textmatch

ColorText.colors = {
    red = 0xFF0000,
    green = 0x00FF00,
    blue = 0x0000FF,
    white = 0xFFFFFF,
    black = 0x000000
} -- todo: get from a config file

ColorText.colors.default_bg = ColorText.colors.black
ColorText.colors.default_fg = ColorText.colors.white

---comment
---@param text any
---@param bg any
---@param fg any
---@param length any
---@param column any
---@return ColorTextStrip
function ColorText.create(text, fg, bg, length, column, row)
    return {text = text, fg = fg, bg = bg, length = length, column = column, row = row}
end

---gets a hex color value from a string
---@param str string
---@return Color
function ColorText.tocolor(str)
    return tonumber(str) or ColorText.colors[string.lower(str)] or error("invalid color: " .. tostring(str))
end

---formats a string to a sequence of ColorTextStrip.
--[[
    special character ¤
    ¤0xFFFFFF: to change background color
    ¤0xFFFFFF- to change foreground color
    ¤XXX= to get arguments.XXX
    \n and \b work. internally they are replaced by ¤\n! (do not type that, that would result in ¤¤\n!!)
    ¤XXX< to open a box and ¤> to close it. closing a box sets the colors back to how they were before opening. todo: can determine if it can be repeated when doing a pattern.
    ¤r< ¤r> to unrotate text, making sure it's upright. 
    todo: a <> that returns the line back
    ¤{XXX} to replace with result of load("XXX")(arguments)
]]
---@param str string
---@param arguments? table<string,string>
---@param env? table environment for loadable
---@return ColorTextStrip[]
function ColorText.format(str, arguments, env)
    str =
        string.gsub(
        str,
        "¤(%b{})",
        function(captured)
            local func, err = load(string.sub(captured, 2, -2), nil, nil, env)
            if func then
                local ok, res = pcall(func, arguments)
                if ok then
                    return tostring(res)
                else
                    return res
                end
            else
                return err
            end
        end
    )
    if arguments then
        str = string.gsub(str, "¤(.-)=", arguments)
    end
    str = "¤!" .. string.gsub(str, "[\n\b]", "¤%0!")

    ---@type ColorTextStrip[]
    local texts = {}
    local column = 0
    local row = 0
    local bg = ColorText.colors.default_bg
    local fg = ColorText.colors.default_fg
    local bg_stack = {}
    local fg_stack = {}
    local stack_size = 0
    local anchor = nil

    for color, special, text in string.gmatch(str, ColorText.gmatch_pattern) do
        if special == "-" then
            fg = ColorText.tocolor(color)
        elseif special == ":" then -- ":"
            bg = ColorText.tocolor(color)
        elseif special == "<" then -- opens a box. when closed returns to current colors
            stack_size = stack_size + 1
            bg_stack[stack_size] = bg
            fg_stack[stack_size] = fg
            if color == "r" then
                anchor = {column, row}
            end
        elseif special == ">" then -- closes a box
            bg = bg_stack[stack_size]
            fg = fg_stack[stack_size]
            stack_size = stack_size - 1
            assert(stack_size >= 0)
            if color == "r" then
                anchor = nil
            end
        elseif special == "!" then
            -- color == "" means this is the beginning string
            if color == "\n" then
                column = 0
                row = row + 1
            elseif color == "\b" then
                column = column - 1
            end
        end

        local length = #text
        if length > 0 then
            local new = ColorText.create(text, fg, bg, length, column, row)
            new.anchor = anchor
            texts[#texts + 1] = new
            column = column + length
        end
    end
    return texts
end

---reverses a single ColorText around its end, which should prepare it for its position being reversed
--[[

    abcd
        dcba
]]
---@param colorText ColorTextStrip
function ColorText.reverse(colorText)
    return ColorText.create(
        string.reverse(colorText.text),
        colorText.fg,
        colorText.bg,
        colorText.length,
        colorText.column + colorText.length,
        colorText.row
    )
end
--- gets a strip that is moved
---@param colorText ColorTextStrip
---@param columns integer
---@param rows integer
function ColorText.move(colorText, columns, rows)
    local ct =
        ColorText.create(
        colorText.text,
        colorText.fg,
        colorText.bg,
        colorText.length,
        colorText.column + columns,
        colorText.row + rows
    )
    if colorText.anchor then
        local ax, ay = table.unpack(colorText.anchor)
        ct.anchor = {ax + columns, ay + rows}
    end
    return ct
end

---comment
---@param texts ColorTextStrip[]
---@param columns integer
---@param rows integer
---@return ColorTextStrip[]
function ColorText.moveAll(texts, columns, rows)
    return Helper.map(
        texts,
        function(value, key)
            return ColorText.move(value, columns, rows)
        end
    )
end

--- returns a substring of ColorText, without moving it, and moving that by dx,dy. returns nil,stop if nothing was left
---@param colorText ColorTextStrip
---@param start integer
---@param stop integer
function ColorText.sub(colorText, start, stop, dx, dy)
    start = math.max(start or -math.huge, 0)
    stop = math.min(stop or math.huge, colorText.length)
    if start >= stop then
        return nil, stop
    end
    return ColorText.create(
        string.sub(colorText.text, start + 1, stop),
        colorText.fg,
        colorText.bg,
        stop - start,
        colorText.column + start + dx,
        colorText.row + dy
    )
end

---like ColorText.sub, but start and stop are not relative
---@param colorText ColorTextStrip
---@param start integer
---@param stop integer
---@param dx integer move the strip
---@param dy integer move the strip
function ColorText.subAnchored(colorText, start, stop, dx, dy)
    return ColorText.sub(colorText, start - colorText.column - dx, stop - colorText.column - dx, dx, dy)
end

---repeats/truncates text until it ends at column `stop`
--- todo: ability to make custom patterns with ¤, such as "this box can be repeated (and truncated (from left/right)), but it has to be balanced with this other box's repeats"
--- todo: a ¤ that does this when formatting.
---@param texts ColorTextStrip[]
---@param start integer
---@param stop integer
---@return ColorTextStrip[]
function ColorText.continuePattern(texts, start, stop)
    local last = texts[#texts]
    local width = (last.column + last.length)
    assert(width > 0, "pattern won't end")
    local height = last.row
    local width_add = 0
    local height_add = 0
    while width_add + width <= start do
        width_add = width_add + width
        height_add = height_add + height
    end
    local out = {}
    while true do
        if width_add > stop then
            return out
        end
        for index, strip in ipairs(texts) do
            local addition, st = ColorText.subAnchored(strip, start, stop, width_add, height_add)
            if not addition and st < 0 then -- todo: is this correct?
                return out
            end
            out[#out + 1] = addition
        end
        width_add = width_add + width
        height_add = height_add + height
    end
end

return ColorText
