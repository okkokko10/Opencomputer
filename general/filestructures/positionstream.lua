---@class positionstream
---@field actualstream buffer
---@field position integer
---@field flushed boolean
---@field offset integer -- start at this position of the actualstream. use to place other data at the beginning.
---@field read_seek_max integer -- how far can read be used to seek. default 2000
positionstream = {}
positionstream.__index = positionstream

---create a positionstream from a stream.
---@param actualstream buffer
---@param offset? integer -- it's like the first `offset` bytes aren't even there
---@return positionstream
function positionstream.make(actualstream, offset)
    assert((offset or 0) >= 0)
    -- position starts as math.huge so that the first seek must set absolute position
    return setmetatable(
        {actualstream = actualstream, position = math.huge, flushed = true, offset = offset or 0, read_seek_max = 2000},
        positionstream
    )
end

function positionstream:setOffset(offset)
    assert(offset >= 0)
    self.offset = offset
end

---comment
---@param position integer
function positionstream:seek(position)
    if position == nil then
        return
    end
    if self.position == position then
        return
    else
        local distance = position - self.position
        ---@diagnostic disable-next-line: undefined-field
        if self.actualstream.mode.r and 0 < distance and distance < self.read_seek_max then -- todo: 1000 is arbitrary.
            self:read(nil, distance) -- often just reading the stream is faster than seeking. not possible for write
        else
            local newpos = self.actualstream:seek("set", position + self.offset) - self.offset
            self.position = newpos
        end
    end
end

function positionstream:write(position, str)
    self:seek(position)
    self.actualstream:write(str)
    self.position = self.position + #str
    self.flushed = false
end

function positionstream:read(position, length)
    self:seek(position)
    local out = self.actualstream:read(length)
    local resultlength = #(out or "")
    self.position = self.position + resultlength
    if resultlength < length then
        return out .. string.rep("\0", length - resultlength)
    end
    return out
end

function positionstream:flush()
    self.flushed = true
    return self.actualstream:flush()
end
function positionstream:close()
    return self.actualstream:close()
end

return positionstream
