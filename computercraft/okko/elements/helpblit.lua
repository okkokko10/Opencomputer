

local hb = {}

function hb.repeatFor(text,n)
    return string.sub(string.rep(text,math.ceil(1+n/string.len(text))),1,n)
end

function hb.blitHet(text,col,back,term_,len)
    local tl = len or string.len(text)
    return (term_ or term).blit(hb.repeatFor(text or " ",tl),hb.repeatFor(col or " ",tl),hb.repeatFor(back or " ",tl))
end

function hb.fill(x,y,hx,hy,setCursorPos,text,col,back, term_)
    for i = y, y+hy-1 do
        setCursorPos(x,i)
        hb.blitHet(text,col,back,term_,hx)
    end
end


return hb