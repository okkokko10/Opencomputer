--term.blit("xyz","abb","..a")

local hb = require("helpblit")

local vn = {}
local hx,hy = term.getSize()
vn.hx = hx
vn.hy = hy

function vn.visualize_one(pos,format)
    term.setCursorPos(pos,1)
    term.blit(format[1],format[2],format[3])
end

function vn.blitXUnit(row,x,text,col,back)
    term.setCursorPos(x*vn.hx,row)
    return hb.blitHet(text,col,back)
end


function vn.visualize(...)
    local a = {...}
    vn.visualize_one(a[1],"xa.")
end

return vn
