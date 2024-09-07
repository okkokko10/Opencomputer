local letterBitmask = {}
local bits_letter = {
    "abcd8",
    "efgh2",
    "ijkl39",
    "mnop0",
    "qrs54",
    "tuvw67",
    "xyz _1"
}
local letter_bits = {}
do
    for index, value in ipairs(bits_letter) do
        for i = 1, #value do
            letter_bits[value:byte(i)] = 1 << (index - 1)
        end
    end
end

---makes a 1-byte bitmask out of the letters that exist in the text.
---@param text string
---@return integer
function letterBitmask.make(text)
    local out = 0
    for i = 1, #text do
        out = out | (letter_bits[text:byte(i)] or 0)
    end
    return out
end

---gets the sum of all chars, mod 256
---@param text string
---@return integer
function letterBitmask.charSum(text)
    local out = 0
    for i = 1, #text do
        out = out + text:byte(i)
    end
    return out & 0xFF
end

---could substring be compared's substring
---accepts values made with letterBitmask.make( )
---("axy","a") -> true
---@param compared integer
---@param substring integer
---@return boolean
function letterBitmask.couldBeSubstring(compared, substring)
    return compared & substring == substring
end

return letterBitmask
