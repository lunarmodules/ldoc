------------
-- Language-dependent parsing of code.
-- This encapsulates the different strategies needed for parsing C and Lua
-- source code.

require 'pl'

local tools = require 'ldoc.tools'
local lexer = require 'ldoc.lexer'

local tnext = lexer.skipws


class.Lang()

function Lang:trim_comment (s)
   return s:gsub(self.line_comment,'')
end

function Lang:start_comment (v)
   local line = v:match (self.start_comment_)
   local block = v:match(self.block_comment)
   return line or block, block
end

function Lang:empty_comment (v)
   return v:match(self.empty_comment_)
end

function Lang:grab_block_comment(v,tok)
   v = v:gsub(self.block_comment,'')
   return tools.grab_block_comment(v,tok,self.end_block1,self.end_block2)
end

function Lang:find_module(tok,t,v)
   return '...',t,v
end

function Lang:function_follows(t,v)
   return false
end

function Lang:finalize()
   self.empty_comment_ = self.start_comment_..'%s*$'
end

function Lang:search_for_token (tok,type,value,t,v)
   while t and not (t == type and v == value) do
      if t == 'comment' and self:start_comment(v) then return nil,t,v end
      t,v = tnext(tok)
   end
   return t ~= nil,t,v
end

function Lang:parse_function_header (tags,tok,toks)
end

function Lang:parse_extra (tags,tok,toks)
end


class.Lua(Lang)

function Lua:_init()
   self.line_comment = '^%-%-+' -- used for stripping
   self.start_comment_ = '^%-%-%-+'     -- used for doc comment line start
   self.block_comment = '^%-%-%[%[%-+' -- used for block doc comments
   self.end_block1 = ']'
   self.end_block2 = ']'
   self:finalize()
end

function Lua.lexer(fname)
   local f,e = io.open(fname)
   if not f then quit(e) end
   return lexer.lua(f,{}),f
end

-- If a module name was not provided, then we look for an explicit module()
-- call. However, we should not try too hard; if we hit a doc comment then
-- we should go back and process it. Likewise, module(...) also means
-- that we must infer the module name.
function Lua:find_module(tok,t,v)
   local res
   res,t,v = self:search_for_token(tok,'iden','module',t,v)
   if not res then return nil,t,v end
   t,v = tnext(tok)
   if t == '(' then t,v = tnext(tok) end
   if t == 'string' then -- explicit name, cool
      return v,t,v
   elseif t == '...' then -- we have to guess!
      return '...',t,v
   end
end

function Lua:function_follows(t,v,tok)
   local is_local = t == 'keyword' and v == 'local'
   if is_local then t,v = tnext(tok) end
   return t == 'keyword' and v == 'function', is_local
end

function Lua:parse_function_header (tags,tok,toks)
   tags.name = tools.get_fun_name(tok)
   tags.formal_args = tools.get_parameters(toks)
   tags.class = 'function'
end

function Lua:parse_extra (tags,tok,toks)
   if tags.class == 'table' and not tags.fields then
      local res
      local stat,t,v = pcall(tok)
      if not stat then return nil end
      res,t,v = self:search_for_token(tok,'{','{',tok())
      if not res then return nil,t,v end
      tags.formal_args = tools.get_parameters(toks,'}',function(s)
         return s == ',' or s == ';'
      end)
   end
end


class.CC(Lang)

function CC:_init()
   self.line_comment = '^//+'
   self.start_comment_ = '^///+'
   self.block_comment = '^/%*%*+'
   self:finalize()
end

function CC.lexer(f)
   f,err = utils.readfile(f)
   if not f then quit(err) end
   return lexer.cpp(f,{})
end

function CC:grab_block_comment(v,tok)
   v = v:gsub(self.block_comment,'')
   return 'comment',v:sub(1,-3)
end

return { lua = Lua(), cc = CC() }
