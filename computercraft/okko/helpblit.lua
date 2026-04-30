

local hb = {}

function hb.repeatFor(text,n)
    return string.sub(string.rep(text,n/string.len(text)),1,n)
end

function hb.blitHet(text,col,back,term_)
    local tl = string.len(text)
    return (term_ or term).blit(text,hb.repeatFor(col or " ",tl),hb.repeatFor(back or " ",tl))
end

return hb