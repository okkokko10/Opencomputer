--- methods for DataFiles that directly read a file
---@class DirectDataFile
---@field filename string
---@field file_offset integer?
local DirectDataFile = {}

function DirectDataFile:openRead()
    self:setRead(io.open(self.filename, "rb"), self.file_offset)
    return self.read_stream
end
function DirectDataFile:openWrite()
    self:setWrite(io.open(self.filename, "ab"), self.file_offset)
    return self.write_stream
end
function DirectDataFile:closeRead()
    if self.read_stream then
        self.read_stream:close()
        self.read_stream = nil
    end
end
function DirectDataFile:closeWrite()
    if self.write_stream then
        self.write_stream:close()
        self.write_stream = nil
    end
end

function DirectDataFile:setRead(stream, offset)
    self:closeRead()
    self.read_stream = positionstream.make(stream, offset)
end

function DirectDataFile:setWrite(stream, offset)
    self:closeWrite()
    self.write_stream = positionstream.make(stream, offset)
end

function DirectDataFile:getRead()
    return self.read_stream or self:openRead() -- todo: this automatically opens a read. is this okay?
end
function DirectDataFile:getWrite()
    return self.write_stream or self:openWrite()
end

return DirectDataFile
