-- parsing code for doc comments

require 'pl'
local lexer = require 'ldoc.lexer'
local tools = require 'ldoc.tools'
local doc = require 'ldoc.doc'
local Item,File = doc.Item,doc.File

------ Parsing the Source --------------
-- This uses the lexer from PL, but it should be possible to use Peter Odding's
-- excellent Lpeg based lexer instead.

local parse = {}

local tnext, append = lexer.skipws, table.insert

-- a pattern particular to LuaDoc tag lines: the line must begin with @TAG,
-- followed by the value, which may extend over several lines.
local luadoc_tag = '^%s*@(%a+)%s(.+)'

-- assumes that the doc comment consists of distinct tag lines
function parse_tags(text)
   local lines = stringio.lines(text)
   local preamble, line = tools.grab_while_not(lines,luadoc_tag)
   local tag_items = {}
   local follows
   while line do
      local tag,rest = line:match(luadoc_tag)
      follows, line = tools.grab_while_not(lines,luadoc_tag)
      append(tag_items,{tag, rest .. '\n' .. follows})
   end
   return preamble,tag_items
end

-- This takes the collected comment block, and uses the docstyle to
-- extract tags and values.  Assume that the summary ends in a period or a question
-- mark, and everything else in the preamble is the description.
-- If a tag appears more than once, then its value becomes a list of strings.
-- Alias substitution and @TYPE NAME shortcutting is handled by Item.check_tag
local function extract_tags (s)
   if s:match '^%s*$' then return {} end
   local preamble,tag_items = parse_tags(s)
   local strip = tools.strip
   local summary,description = preamble:match('^(.-[%.?])%s(.+)')
   if not summary then summary = preamble end  --  and strip(description) ?
   local tags = {summary=summary and strip(summary),description=description}
   for _,item in ipairs(tag_items) do
      local tag,value = item[1],item[2]
      tag = Item.check_tag(tags,tag)
      value = strip(value)
      local old_value = tags[tag]
      if old_value then
         if type(old_value)=='string' then tags[tag] = List{old_value} end
         tags[tag]:append(value)
      else
         tags[tag] = value
      end
   end
   return Map(tags)
end



-- parses a Lua or C file, looking for ldoc comments. These are like LuaDoc comments;
-- they start with multiple '-'. (Block commments are allowed)
-- If they don't define a name tag, then by default
-- it is assumed that a function definition follows. If it is the first comment
-- encountered, then ldoc looks for a call to module() to find the name of the
-- module if there isn't an explicit module name specified.

local function parse_file(fname,lang, package)
   local line,f = 1
   local F = File(fname)
   local module_found, first_comment = false,true

   local tok,f = lang.lexer(fname)

    function lineno ()
      return tok:lineno()
    end

   function filename () return fname end

   function F:warning (msg,kind)
      kind = kind or 'warning'
      io.stderr:write(kind..' '..fname..':'..lineno()..' '..msg,'\n')
   end

   function F:error (msg)
      self:warning(msg,'error')
      os.exit(1)
   end

   local function add_module(tags,module_found,old_style)
      tags.name = module_found
      tags.class = 'module'
      local item = F:new_item(tags,pcall(lineno) or 1)
      item.old_style = old_style
   end

   local mod
   local t,v = tnext(tok)
   if lang.parse_module_call and t ~= 'comment'then
      while t and not (t == 'iden' and v == 'module') do
         t,v = tnext(tok)
      end
      if not t then
         F:warning("no module() call found; no initial doc comment")
      else
         mod,t,v = lang:parse_module_call(tok,t,v)
         if mod ~= '...' then
            add_module({summary='(no description)'},mod,true)
            first_comment = false
            module_found = true
         end
      end
   end
   while t do
      if t == 'comment' then
         local comment = {}
         local ldoc_comment,block = lang:start_comment(v)
         if ldoc_comment and v:match '%-+$' then
            ldoc_comment = false
         end

         if ldoc_comment and block then
            t,v = lang:grab_block_comment(v,tok)
         end

         if lang:empty_comment(v)  then -- ignore rest of empty start comments
            t,v = tok()
         end

         while t and t == 'comment' do
            v = lang:trim_comment(v)
            append(comment,v)
            t,v = tok()
            if t == 'space' and not v:match '\n' then
               t,v = tok()
            end
         end
         if not t then break end -- no more file!

         if t == 'space' then t,v = tnext(tok) end

         local item_follows, tags, is_local
         if ldoc_comment or first_comment then
            comment = table.concat(comment)
            if not ldoc_comment and first_comment then
               F:warning("first comment must be a doc comment!")
               break
            end
            first_comment = false
            item_follows, is_local = lang:item_follows(t,v,tok)
            if item_follows or comment:find '@'then
               tags = extract_tags(comment)
               if doc.project_level(tags.class) then
                  module_found = tags.name
               end
               if tags.name then
                  item_follows, is_local = false, false
               end
            end
         end
         -- some hackery necessary to find the module() call
         if not module_found and ldoc_comment then
            local old_style
            module_found,t,v = lang:find_module(tok,t,v)
            -- right, we can add the module object ...
            old_style = module_found ~= nil
            if not module_found or module_found == '...' then
               -- we have to guess the module name
               module_found = tools.this_module_name(package,fname)
            end
            if not tags then tags = extract_tags(comment) end
            add_module(tags,module_found,old_style)
            tags = nil
            if not t then
               io.stderr:write('warning: ',fname,' contains no items\n')
               break;
            end -- run out of file!
            -- if we did bump into a doc comment, then we can continue parsing it
         end

         -- end of a block of document comments
         if ldoc_comment and tags then
            local line = t ~= nil and lineno() or 666
            if t ~= nil then
               if item_follows then -- parse the item definition
                  item_follows(tags,tok)
               else
                  lang:parse_extra(tags,tok)
               end
            end
            -- local functions treated specially
            if tags.class == 'function' and (is_local or tags['local']) then
               tags.class = 'lfunction'
            end
            if tags.name then
               F:new_item(tags,line).inferred = item_follows ~= nil
            end
            if not t then break end
         end
      end
      if t ~= 'comment' then t,v = tok() end
   end
   if f then f:close() end
   return F
end

function parse.file(name,lang, args)
   local F,err = parse_file(name,lang, args.package)
   if err then return nil,err end
   F:finish()
   return F
end

return parse
