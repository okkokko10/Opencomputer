local function unserialize(data)
    checkArg(1, data, "string")
    return select(2, pcall(load("return " .. data, "=data", nil, {math = {huge = math.huge}})))
end

local function serialize(data)
    local t = type(data)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        return tostring(data)
    elseif t == "string" then
        return '"' .. data .. '"'
    elseif t == "boolean" then
        return t and "true" or "false"
    elseif t == "table" then
        local out = "{"
        for k, v in pairs(data) do
            out = out .. "[" .. serialize(k) .. "]" .. "=" .. serialize(v) .. ","
        end
        return out .. "}"
    end
end

return serialize
