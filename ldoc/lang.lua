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
   return tools.grab_block_comment(v,tok,self.end_comment)
end

function Lang:find_module(tok,t,v)
   return '...',t,v
end

function Lang:item_follows(t,v)
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

function Lang:parse_extra (tags,tok)
end


class.Lua(Lang)

function Lua:_init()
   self.line_comment = '^%-%-+' -- used for stripping
   self.start_comment_ = '^%-%-%-+'     -- used for doc comment line start
   self.block_comment = '^%-%-%[=*%[%-+' -- used for block doc comments
   self:finalize()
end

function Lua.lexer(fname)
   local f,e = io.open(fname)
   if not f then quit(e) end
   return lexer.lua(f,{}),f
end

function Lua:grab_block_comment(v,tok)
   local equals = v:match('^%-%-%[(=*)%[')
   v = v:gsub(self.block_comment,'')
   return tools.grab_block_comment(v,tok,'%]'..equals..'%]')
end


function Lua:parse_module_call(tok,t,v)
   t,v = tnext(tok)
   if t == '(' then t,v = tnext(tok) end
   if t == 'string' then -- explicit name, cool
      return v,t,v
   elseif t == '...' then -- we have to guess!
      return '...',t,v
   end
end

-- If a module name was not provided, then we look for an explicit module()
-- call. However, we should not try too hard; if we hit a doc comment then
-- we should go back and process it. Likewise, module(...) also means
-- that we must infer the module name.
function Lua:find_module(tok,t,v)
   local res
   res,t,v = self:search_for_token(tok,'iden','module',t,v)
   if not res then return nil,t,v end
   return self:parse_module_call(tok,t,v)
end

local function parse_lua_parameters (tags,tok)
   tags.formal_args = tools.get_parameters(tok)
   tags.class = 'function'
end

local function parse_lua_function_header (tags,tok)
   tags.name = tools.get_fun_name(tok)
   parse_lua_parameters(tags,tok)
end

local function parse_lua_table (tags,tok)
   tags.formal_args = tools.get_parameters(tok,'}',function(s)
      return s == ',' or s == ';'
   end)
end

--------------- function and variable inferrence -----------
-- After a doc comment, there may be a local followed by:
-- [1] (l)function: function NAME
-- [2] (l)function: NAME = function
-- [3] table: NAME = {
-- [4] field: NAME = <anything else>  (this is a module-level field)
--
-- Depending on the case successfully detected, returns a function which
-- will be called later to fill in inferred item tags
function Lua:item_follows(t,v,tok)
   local parser
   local is_local = t == 'keyword' and v == 'local'
   if is_local then t,v = tnext(tok) end
   if t == 'keyword' and v == 'function' then -- case [1]
      parser = parse_lua_function_header
   elseif t == 'iden' then
      local name,t,v = tools.get_fun_name(tok,v)
      if t ~= '=' then return nil end -- probably invalid code...
      t,v = tnext(tok)
      if t == 'keyword' and v == 'function' then -- case [2]
         tnext(tok) -- skip '('
         parser = function(tags,tok)
            tags.name = name
            parse_lua_parameters(tags,tok)
         end
      elseif t == '{' then -- case [3]
         parser = function(tags,tok)
            tags.class = 'table'
            tags.name = name
            parse_lua_table (tags,tok)
         end
      else -- case [4]
         parser = function(tags)
            tags.class = 'field'
            tags.name = name
         end
      end
   end
   return parser, is_local
end


-- this is called, whether the tag was inferred or not.
-- Currently tries to fill in the fields of a table from comments
function Lua:parse_extra (tags,tok)
   if tags.class == 'table' and not tags.field then
      local res, stat
      if t ~= '{' then
         stat,t,v = pcall(tok)
         if not stat then return nil end
         res,t,v = self:search_for_token(tok,'{','{',tok())
         if not res then return nil,t,v end
      end
      parse_lua_table (tags,tok)
   end
end

-- note a difference here: we scan C/C++ code in full-text mode, not line by line.
-- This is because we can't detect multiline comments in line mode

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
