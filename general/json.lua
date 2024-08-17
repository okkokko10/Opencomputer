local json = {}

---@alias Object any

--- represents null
json.null = setmetatable({}, {__name = "null"})

---@param text string
---@param init integer
---@return Object,integer
local function getObject(text, init)
    local current = init + 1
    local keyvalues = {}
    while true do
        local key, afterKey = json.parse(text, current)
        if type(key) ~= "string" then
            error("non-string key: " .. string.sub(text, current, afterKey - 1))
        end
        local colon, afterColon = string.match(text, "(%S)()", afterKey)
        if colon ~= ":" then
            error(
                'unexpected "' ..
                    colon ..
                        '"' ..
                            " at index" ..
                                afterColon - 1 .. ": ..." .. string.sub(text, afterColon - 10, afterColon + 10) .. "..."
            )
        end
        local value, afterValue = json.parse(text, afterColon)
        local separator, afterSep = string.match(text, "(%S)()", afterValue)

        keyvalues[key] = value
        current = afterSep
        if separator == "," then
        elseif separator == "}" then
            return keyvalues, afterSep
        else
            error(
                'unexpected "' ..
                    separator ..
                        '"' ..
                            " at index" ..
                                afterSep - 1 .. ": ..." .. string.sub(text, afterSep - 10, afterSep + 10) .. "..."
            )
        end
    end
end
---@param text string
---@param init integer
---@return Object,integer
local function getString(text, init)
    local current = init + 1
    while true do
        --- position of currently examined "
        local escapes, place = string.match(text, '(\\*)()"', current)
        if not place then
            error(
                "unclosed string starting at index" ..
                    init .. ": ..." .. string.sub(text, init - 10, init + 10) .. "..."
            )
        end
        -- local escapeNumber = place - 1
        -- while string.sub(text, escapeNumber, escapeNumber) == "\\" do
        --     escapeNumber = escapeNumber - 1
        -- end
        -- if (place - escapeNumber) % 2 == 0 then
        --     -- \" or \\\", so escapes
        --     current = place + 1
        -- else
        --     --- " or \\", so doesn't escape.
        if #escapes % 2 == 0 then
            return string.sub(text, init + 1, place - 1), place + 1
        else
            current = place + 1
        end
    end
end
---@param text string
---@param init integer
---@return Object,integer
local function getArray(text, init)
    local current = init + 1
    local elements = {}
    while true do
        local element, next = json.parse(text, current)
        elements[#elements + 1] = element
        local separator, after = string.match(text, "(%S)()", next)
        current = after
        if separator == "," then
        elseif separator == "]" then
            return elements, after
        else
            error(
                'unexpected "' ..
                    separator ..
                        '"' .. " at index" .. after - 1 .. ": ..." .. string.sub(text, after - 10, after + 10) .. "..."
            )
        end
    end
end

---number, true, false, null
---@param text string
---@param init integer
---@return Object,integer
local function getSimple(text, init, char)
    if char == "t" then
        local after = string.match(text, "^true()", init)
        if after then
            return true, after
        end
    elseif char == "f" then
        local after = string.match(text, "^false()", init)
        if after then
            return true, after
        end
    elseif char == "n" then
        local after = string.match(text, "^null()", init)
        if after then
            return json.null, after
        end
    end
    local value, after = string.match(text, "^(.-)()%f[%:%,%]%}%s\0]", init)
    local main, ending = string.match(value, "^(.-)([Lb]?)$")
    if ending == "b" then
        if value == "1b" then
            return true, after
        elseif value == "0b" then
            return false, after
        end
    end
    local num = tonumber(main)
    if num then
        return num, after
    else
        return value, after --- if the value is not recognized, return it as a string as a fallback.
    end
end

--- init is the index of the beginning, 1 by default
--- returns Object and the index of the next character after the object
---@param text string
---@param init? integer
---@return Object,integer
function json.parse(text, init)
    ---@type integer,string
    local start, char = string.match(text, "()(%S)", init or 1)
    if char == "{" then
        return getObject(text, start)
    elseif char == '"' then
        return getString(text, start)
    elseif char == "[" then
        return getArray(text, start)
    elseif string.find("]}:,", char) then
        error(
            'unexpected "' ..
                char .. '" at index ' .. start .. ": ..." .. string.sub(text, start - 10, start + 10) .. "..."
        )
    else
        return getSimple(text, start, char)
    end
end

return json
