require 'pl'
local lexer = require 'ldoc.lexer'
local prettify = {}

local escaped_chars = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
}
local escape_pat = '[&<>]'

local function escape(str)
    return (str:gsub(escape_pat,escaped_chars))
end

local function span(t,val)
    return ('<span class="%s">%s</span>'):format(t,val)
end

local function link(file,ref,text)
    text = text or ref
    return ('<a class="L" href="%s.html#%s">%s</a>'):format(file,ref,text)
end

local spans = {keyword=true,number=true,string=true,comment=true}

function prettify.lua (file)
    local code,err = utils.readfile(file)
    if not code then return nil,err end

    local res = List()
    res:append(header)
    res:append '<pre>\n'

    local tok = lexer.lua(code,{},{})
    local t,val = tok()
    while t do
        val = escape(val)
        if spans[t] then
            res:append(span(t,val))
        else
            res:append(val)
        end
        --print(t,'|'..val..'|')
        t,val = tok()
    end
    res:append(footer)
    return res:join ()
end

return prettify
