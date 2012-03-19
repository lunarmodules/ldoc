-- Making Lua source code look pretty.
-- A simple scanner based prettifier, which scans comments for @{ref} and code
-- for known modules and functions.
-- A module reference to an example `test-fun.lua` would look like
-- `@{example:test-fun}`.
require 'pl'
local lexer = require 'ldoc.lexer'
local globals = require 'ldoc.builtin.globals'
local tnext = lexer.skipws
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

local spans = {keyword=true,number=true,string=true,comment=true,global=true}

function prettify.lua (fname, code, initial_lineno)
   local res = List()
   res:append(header)
   res:append '<pre>\n'
   intial_lineno = initial_lineno or 0

   local tok = lexer.lua(code,{},{})
   local error_reporter = {
      warning = function (self,msg)
         io.stderr:write(fname..':'..tok:lineno()+initial_lineno..': '..msg,'\n')
      end
   }
   local t,val = tok()
   if not t then return nil,"empty file" end
   while t do
      val = escape(val)
      if globals.functions[val] or globals.tables[val] then
         t = 'global'
      end
      if spans[t] then
         if t == 'comment' then -- may contain @{ref}
            val = prettify.resolve_inline_references(val,error_reporter)
         end
         res:append(span(t,val))
      else
         res:append(val)
      end
      t,val = tok()
   end
   local last = res[#res]
   if last:match '\n$' then
      res[#res] = last:gsub('\n+','')
   end
   return res:join ()
end

return prettify

