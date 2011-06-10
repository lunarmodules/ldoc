------
-- Defining the ldoc document model.


require 'pl'

local doc = {}

local tools = require 'tools'
local split_dotted_name = tools.split_dotted_name

-- these are the basic tags known to ldoc. They come in several varieties:
--  - tags with multiple values like 'param' (TAG_MULTI)
--  - tags which are identifiers, like 'name' (TAG_ID)
--  - tags with a single value, like 'release' (TAG_SINGLE)
--  - tags which represent a type, like 'function' (TAG_TYPE)
local known_tags = {
   param = 'M', see = 'M', usage = 'M', ['return'] = 'M', field = 'M', author='M';
   class = 'id', name = 'id', pragma = 'id', alias = 'id';
   copyright = 'S', summary = 'S', description = 'S', release = 'S', license = 'S';
   module = 'T', script = 'T',['function'] = 'T', table = 'T', section = 'T', type = 'T';
}
known_tags._alias = {}
known_tags._project_level = {
   module = true,
   script = true
}

local TAG_MULTI,TAG_ID,TAG_SINGLE,TAG_TYPE = 'M','id','S','T'
doc.TAG_MULTI,doc.TAG_ID,doc.TAG_SINGLE,doc.TAG_TYPE = TAG_MULTI,TAG_ID,TAG_SINGLE,TAG_TYPE

-- add a new tag.
function doc.add_tag(tag,type,project_level)
   if not known_tags[tag] then
      known_tags[tag] = type
      known_tags._project_level[tag] = project_level
   end
end

-- add an alias to an existing tag (exposed through ldoc API)
function doc.add_alias (a,tag)
   known_tags._alias[a] = tag
end

-- get the tag alias value, if it exists.
function doc.get_alias(tag)
   return known_tags._alias[tag]
end

-- is it a'project level' tag, such as 'module' or 'script'?
function doc.project_level(tag)
   return known_tags._project_level[tag]
end

-- is it a section tag, like 'type' (class) or 'section'?
function doc.section_tag (tag)
   return tag == 'section' or tag == 'type'
end

-- we process each file, resulting in a File object, which has a list of Item objects.
-- Items can be modules, scripts ('project level') or functions, tables, etc.
-- (In the code 'module' refers to any project level tag.)
-- When the File object is finalized, we specialize some items as modules which
-- are 'container' types containing functions and tables, etc.

local File = class()
local Item = class()
local Module = class(Item) -- a specialized kind of Item

doc.File = File
doc.Item = Item
doc.Module = Module

function File:_init(filename)
   self.filename = filename
   self.items = List()
   self.modules = List()
end

function File:new_item(tags,line)
   local item = Item(tags)
   self.items:append(item)
   item.file = self
   item.lineno = line
   return item
end

function File:finish()
   local this_mod
   local items = self.items
   for item in items:iter() do
      item:finish()
      if doc.project_level(item.type) then
         this_mod = item
         -- if name is 'package.mod', then mod_name is 'mod'
         local package,mname = split_dotted_name(this_mod.name)
         if not package then
            mname = this_mod.name
            package = ''
         else
            package = package .. '.'
         end
         self.modules:append(this_mod)
         this_mod.package = package
         this_mod.mod_name = mname
         this_mod.kinds = ModuleMap() -- the iterator over the module contents
      elseif doc.section_tag(item.type) then
         local display_name = item.name
         if display_name == 'end' then
            this_mod.section = nil
         else
            local summary = item.summary:gsub('%.$','')
            if item.type == 'type' then
               display_name = 'Class '..item.name
               item.module = this_mod
               this_mod.items.by_name[item.name] = item
            else
               display_name = summary
            end
            item.display_name = display_name
            this_mod.section = item
            this_mod.kinds:add_kind(display_name,display_name)
         end
      else
         -- add the item to the module's item list
         if this_mod then
            -- new-style modules will have qualified names like 'mod.foo'
            local mod,fname = split_dotted_name(item.name)
            -- warning for inferred unqualified names in new style modules
            -- (retired until we handle methods like Set:unset() properly)
            if not mod and not this_mod.old_style and item.inferred then
               --item:warning(item.name .. ' is declared in global scope')
            end
            -- the function may be qualified with a module alias...
            if this_mod.tags.alias and mod == this_mod.tags.alias then
               mod = this_mod.mod_name
            end
            -- if that's the mod_name, then we want to only use 'foo'
            if mod == this_mod.mod_name and this_mod.tags.pragma ~= 'nostrip' then
               item.name = fname
            end

            -- right, this item was within a section or a 'class'
            local section_description
            if this_mod.section then
               item.section = this_mod.section.display_name
               -- if it was a class, then the name should be 'Class.foo'
               if this_mod.section.type == 'type' then
                  item.name = this_mod.section.name .. '.' .. item.name
               end
               section_description = this_mod.section.description
            else -- otherwise, just goes into the default sections (Functions,Tables,etc)
               item.section = item.type
            end

            item.module = this_mod
            local these_items = this_mod.items
            these_items.by_name[item.name] = item
            these_items:append(item)

            -- register this item with the iterator
            this_mod.kinds:add(item,these_items,section_description)

         else
            -- must be a free-standing function (sometimes a problem...)
         end
      end
   end
end

function Item:_init(tags)
   self.summary = tags.summary
   self.description = tags.description
   tags.summary = nil
   tags.description = nil
   self.tags = {}
   self.formal_args = tags.formal_args
   tags.formal_args = nil
   for tag,value in pairs(tags) do
      local ttype = known_tags[tag]
      if ttype == TAG_MULTI then
         if type(value) == 'string' then
            value = List{value}
         end
         self.tags[tag] = value
      elseif ttype == TAG_ID then
         if type(value) ~= 'string' then
            -- such tags are _not_ multiple, e.g. name
            self:error(tag..' cannot have multiple values')
         else
            self.tags[tag] = tools.extract_identifier(value)
         end
      elseif ttype == TAG_SINGLE then
         self.tags[tag] = value
      else
         self:warning ('unknown tag: '..tag)
      end
   end
end

-- preliminary processing of tags. We check for any aliases, and for tags
-- which represent types. This implements the shortcut notation.
function Item.check_tag(tags,tag)
   tag = doc.get_alias(tag) or tag
   local ttype = known_tags[tag]
   if ttype == TAG_TYPE then
      tags.class = tag
      tag = 'name'
   end
   return tag
end


function Item:finish()
   local tags = self.tags
   self.name = tags.name
   self.type = tags.class
   self.usage = tags.usage
   tags.name = nil
   tags.class = nil
   tags.usage = nil
   -- see tags are multiple, but they may also be comma-separated
   if tags.see then
      tags.see = tools.expand_comma_list(tags.see)
   end
   if  doc.project_level(self.type) then
      -- we are a module, so become one!
      self.items = List()
      self.items.by_name = {}
      setmetatable(self,Module)
   elseif not doc.section_tag(self.type) then
      -- params are either a function's arguments, or a table's fields, etc.
      local params
      if self.type == 'function' then
         params = tags.param or List()
         if tags['return'] then
            self.ret = tags['return']
         end
      else
         params = tags.field or List()
      end
      tags.param = nil
      local names,comments = List(),List()
      for p in params:iter() do
         local name,comment = p:match('%s*([%w_%.:]+)(.*)')
         names:append(name)
         comments:append(comment)
      end
      -- not all arguments may be commented --
      if self.formal_args then
         -- however, ldoc allows comments in the arg list to be used
         local fargs = self.formal_args
         for a in fargs:iter() do
            if not names:index(a) then
               names:append(a)
               comments:append (fargs.comments[a] or '')
            end
         end
      end
      self.params = names
      for i,name in ipairs(self.params) do
         self.params[name] = comments[i]
      end
      self.args = '('..self.params:join(', ')..')'
   end
end

function Item:warning(msg)
   local name = self.file and self.file.filename
   if type(name) == 'table' then pretty.dump(name); name = '?' end
   name = name or '?'
   io.stderr:write(name,':',self.lineno or '?',' ',msg,'\n')
end

-- resolving @see references. A word may be either a function in this module,
-- or a module in this package. A MOD.NAME reference is within this package.
-- Otherwise, the full qualified name must be used.
-- First, check whether it is already a fully qualified module name.
-- Then split it and see if the module part is a qualified module
-- and try look up the name part in that module.
-- If this isn't successful then try prepending the current package to the reference,
-- and try to to resolve this.
function Module:resolve_references(modules)
   local found = List()

   local function process_see_reference (item,see,s)
      local mod_ref,fun_ref,name,packmod
      -- is this a fully qualified module name?
      local mod_ref = modules.by_name[s]
      if mod_ref then return mod_ref,nil end
      local packmod,name = split_dotted_name(s) -- e.g. 'pl.utils','split'
      if packmod then -- qualified name
         mod_ref = modules.by_name[packmod] -- fully qualified mod name?
         if not mod_ref then
            mod_ref = modules.by_name[self.package..packmod]
         end
         if not mod_ref then
            item:warning("module not found: "..packmod)
            return nil
         end
         fun_ref = mod_ref.items.by_name[name]
         if fun_ref then
            return mod_ref,fun_ref
         else
            item:warning("function not found: "..s.." in "..mod_ref.name)
         end
      else -- plain jane name; module in this package, function in this module
         mod_ref = modules.by_name[self.package..s]
         if mod_ref then return mod_ref,nil end
         fun_ref = self.items.by_name[s]
         if fun_ref then return self,fun_ref
         else
            item:warning("function not found: "..s.." in this module")
         end
      end
   end

   for item in self.items:iter() do
      local see = item.tags.see
      if see then -- this guy has @see references
         item.see = List()
         for s in see:iter() do
            local mod_ref, item_ref = process_see_reference(item,see,s)
            if mod_ref then
               local name = item_ref and item_ref.name or ''
               -- this is deeply hacky; classes have 'Class ' prepended.
               if item_ref and item_ref.type == 'type' then
                  name = 'Class_'..name
               end
               item.see:append {mod=mod_ref.name,name=name,label=s}
               found:append{item,s}
            end
         end
      end
   end
   -- mark as found, so we don't waste time re-searching
   for f in found:iter() do
      f[1].tags.see:remove_value(f[2])
   end
end

-- make a text dump of the contents of this File object.
-- The level of detail is controlled by the 'verbose' parameter.
-- Primarily intended as a debugging tool.
function File:dump(verbose)
   for mod in self.modules:iter() do
      mod:dump(verbose)
   end
end

function Module:dump(verbose)
   print '----'
   print(self.type..':',self.name,self.summary)
   if self.description then print(self.description) end
   for item in self.items:iter() do
      item:dump(verbose)
   end
end

function Item:dump(verbose)
   local tags = self.tags
   local name = self.name
   if self.type == 'function' then
      name = name .. self.args
   end
   if verbose then
      print()
      print(self.type,name)
      print(self.summary)
      if self.description then print(self.description) end
      for _,p in ipairs(self.params) do
         print(p,self.params[p])
      end
      for tag, value in pairs(self.tags) do
         print(tag,value)
      end
   else
      print('* '..name..' - '..self.summary)
   end
end

return doc

