------
-- Defining the ldoc document model.


require 'pl'

local doc = {}
local global = require 'ldoc.builtin.globals'
local tools = require 'ldoc.tools'
local split_dotted_name = tools.split_dotted_name

-- these are the basic tags known to ldoc. They come in several varieties:
--  - tags with multiple values like 'param' (TAG_MULTI)
--  - tags which are identifiers, like 'name' (TAG_ID)
--  - tags with a single value, like 'release' (TAG_SINGLE)
--  - tags which represent a type, like 'function' (TAG_TYPE)
local known_tags = {
   param = 'M', see = 'M', usage = 'M', ['return'] = 'M', field = 'M', author='M';
   class = 'id', name = 'id', pragma = 'id', alias = 'id';
   copyright = 'S', summary = 'S', description = 'S', release = 'S', license = 'S',
   fixme = 'S', todo = 'S', warning = 'S', raise = 'S';
   module = 'T', script = 'T', example = 'T', topic = 'T', -- project-level
   ['function'] = 'T', lfunction = 'T', table = 'T', section = 'T', type = 'T',
   annotation = 'T'; -- module-level
   ['local'] = 'N', export = 'N';
}
known_tags._alias = {}
known_tags._project_level = {
   module = true,
   script = true,
   example = true,
   topic = true
}

local TAG_MULTI,TAG_ID,TAG_SINGLE,TAG_TYPE,TAG_FLAG = 'M','id','S','T','N'
doc.TAG_MULTI,doc.TAG_ID,doc.TAG_SINGLE,doc.TAG_TYPE,doc.TAG_FLAG =
    TAG_MULTI,TAG_ID,TAG_SINGLE,TAG_TYPE,TAG_FLAG

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


-- annotation tags can appear anywhere in the code and may contain of these tags:
known_tags._annotation_tags = {
   fixme = true, todo = true, warning = true
}

local acount = 1

function doc.expand_annotation_item (tags, last_item)
   if tags.summary ~= '' then return false end
   for tag, value in pairs(tags) do
      if known_tags._annotation_tags[tag] then
         tags.class = 'annotation'
         tags.summary = value
         local item_name = last_item and last_item.tags.name or '?'
         tags.name = item_name..'-'..tag..acount
         acount = acount + 1
         return true
      end
   end
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
   self.sections = List()
end

function File:new_item(tags,line)
   local item = Item(tags,self,line or 1)
   self.items:append(item)
   return item
end

function File:export_item (name)
   for item in self.items:iter() do
      local tags = item.tags
      if tags.name == name then
         if tags['local'] then
            tags['local'] = false
         end
      end
   end
end

function File:finish()
   local this_mod
   local items = self.items
   for item in items:iter() do
      item:finish()
      if doc.project_level(item.type) then
         this_mod = item
         local package,mname
         if item.type == 'module' then
            -- if name is 'package.mod', then mod_name is 'mod'
            package,mname = split_dotted_name(this_mod.name)
         end
         if not package then
            mname = this_mod.name
            package = ''
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
            this_mod.sections:append(item)
            this_mod.sections.by_name[display_name:gsub('%A','_')] = item
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
            local alias = this_mod.tags.alias
            if (alias and mod == alias) or mod == 'M' or mod == '_M' then
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
               -- if it was a class, then the name should be 'Class:foo'
               if this_mod.section.type == 'type' then
                  local prefix = this_mod.section.name .. ':'
                  local i1,i2 = item.name:find(prefix)
                  if not (i1 == 1 and i2 == #prefix) then
                     item.name =  prefix .. item.name
                  end
               end
               section_description = this_mod.section.description
            else -- otherwise, just goes into the default sections (Functions,Tables,etc)
               item.section = item.type
            end

            item.module = this_mod
            local these_items = this_mod.items
            these_items.by_name[item.name] = item
            these_items:append(item)

            this_mod.kinds:add(item,these_items,section_description)

         else
            -- must be a free-standing function (sometimes a problem...)
         end
      end
   end
end

-- some serious hackery. We force sections into this 'module',
-- and ensure that there is a dummy item so that the section
-- is not empty.

function File:add_document_section(title)
   local section = title:gsub('%A','_')
   self:new_item {
      name = section,
      class = 'section',
      summary = title
   }
   self:new_item {
      name = 'dumbo',
      class = 'function',
   }
   return section
end

function Item:_init(tags,file,line)
   self.file = file
   self.lineno = line
   self.summary = tags.summary
   self.description = tags.description
   tags.summary = nil
   tags.description = nil
   self.tags = {}
   self.formal_args = tags.formal_args
   tags.formal_args = nil
   for tag,value in pairs(tags) do
      self:set_tag(tag,value)
   end
end

function Item:set_tag (tag,value)
   local ttype = known_tags[tag]
   if ttype == TAG_MULTI then
      if getmetatable(value) ~= List then
         value = List{value}
      end
      self.tags[tag] = value
   elseif ttype == TAG_ID then
      if type(value) ~= 'string' then
         -- such tags are _not_ multiple, e.g. name
         self:error("'"..tag.."' cannot have multiple values")
      else
         self.tags[tag] = tools.extract_identifier(value)
      end
   elseif ttype == TAG_SINGLE then
      self.tags[tag] = value
   elseif ttype == TAG_FLAG then
      self.tags[tag] = true
   else
      Item.warning(self,"unknown tag: '"..tag.."' "..tostring(ttype))
   end
end

-- preliminary processing of tags. We check for any aliases, and for tags
-- which represent types. This implements the shortcut notation.
function Item.check_tag(tags,tag, value, modifiers)
   local alias = doc.get_alias(tag)
   if alias then
      if type(alias) == 'string' then
         tag = alias
      else
         local avalue,amod
         tag, avalue, amod = alias[1],alias.value,alias.modifiers
         if avalue then value = avalue..' '..value end
         if amod then
            modifiers = modifiers or {}
            for m,v in pairs(amod) do
               local idx = v:match('^%$(%d+)')
               if idx then
                  v, value = value:match('(%S+)(.*)')
               end
               modifiers[m] = v
            end
         end
      end
   end
   local ttype = known_tags[tag]
   if ttype == TAG_TYPE then
      tags.class = tag
      tag = 'name'
   end
   return tag, value, modifiers
end

-- any tag (except name and classs) may have associated modifiers,
-- in the form @tag[m1,...] where  m1 is either name1=value1 or name1.
-- At this stage, these are encoded
-- in the tag value table and need to be extracted.

local function extract_value_modifier (p)
   if type(p)=='string' then
      return p, { }
   elseif type(p) == 'table' then
      return p[1], p.modifiers or { }
   else
      return 'que?',{}
   end
end

local function extract_tag_modifiers (tags)
   local modifiers = {}
   for tag, value in pairs(tags) do
      if type(value)=='table' and value.append then
         local tmods = {}
         for i, v in ipairs(value) do
            v, mods = extract_value_modifier(v)
            tmods[i] = mods
            value[i] = v
         end
         modifiers[tag] = tmods
      else
         value, mods = extract_value_modifier(value)
         modifiers[tag] = mods
         tags[tag] = value
      end
   end
   return modifiers
end

local function read_del (tags,name)
   local ret = tags[name]
   tags[name] = nil
   return ret
end


function Item:finish()
   local tags = self.tags
   local quote = tools.quote
   self.name = read_del(tags,'name')
   self.type = read_del(tags,'class')
   self.modifiers = extract_tag_modifiers(tags)
   self.usage = read_del(tags,'usage')
   -- see tags are multiple, but they may also be comma-separated
   if tags.see then
      tags.see = tools.expand_comma_list(read_del(tags,'see'))
   end
   if  doc.project_level(self.type) then
      -- we are a module, so become one!
      self.items = List()
      self.sections = List()
      self.items.by_name = {}
      self.sections.by_name = {}
      setmetatable(self,Module)
   elseif not doc.section_tag(self.type) then
      -- params are either a function's arguments, or a table's fields, etc.
      if self.type == 'function' then
         self.parameter = 'param'
         self.ret = read_del(tags,'return')
         self.raise = read_del(tags,'raise')
         if tags['local'] then
            self.type = 'lfunction'
         end
      else
         self.parameter = 'field'
      end
      local params = read_del(tags,self.parameter)
      local names, comments, modifiers = List(), List(), List()
      if params then
         for line in params:iter() do
            local name, comment = line :match('%s*([%w_%.:]+)(.*)')
            assert(name, "bad param name format")
            names:append(name)
            comments:append(comment)
         end
      end
      -- not all arguments may be commented: we use the formal arguments
      -- if available as the authoritative list, and warn if there's an inconsistency.
      if self.formal_args then
         local fargs = self.formal_args
         if #fargs ~= 1 then
            local pnames, pcomments = names, comments
            names, comments = List(),List()
            local varargs = fargs[#fargs] == '...'
            for i,name in ipairs(fargs) do
               if params then -- explicit set of param tags
                  if pnames[i] ~= name and not varargs then
                     if pnames[i] then
                        self:warning("param and formal argument name mismatch: "..quote(name).." "..quote(pnames[i]))
                     else
                        self:warning("undocumented formal argument: "..quote(name))
                     end
                  elseif varargs then
                     name = pnames[i]
                  end
               end
               names:append(name)
               -- ldoc allows comments in the formal arg list to be used
               comments:append (fargs.comments[name] or pcomments[i] or '')
            end
            -- A formal argument of ... may match any number of params, however.
            if #pnames > #fargs then
               for i = #fargs+1,#pnames do
                  if not varargs then
                     self:warning("extra param with no formal argument: "..quote(pnames[i]))
                  else
                     names:append(pnames[i])
                     comments:append(pcomments[i] or '')
                  end
               end
            end
         end
      end

      -- the comments are associated with each parameter by
      -- adding name-value pairs to the params list (this is
      -- also done for any associated modifiers)
      self.params = names
      local pmods = self.modifiers[self.parameter]
      for i,name in ipairs(self.params) do
         self.params[name] = comments[i]
         if pmods then
            pmods[name] = pmods[i]
         end
      end

      -- build up the string representation of the argument list,
      -- using any opt and optchain modifiers if present.
      -- For instance, '(a [, b])' if b is marked as optional
      -- with @param[opt] b
      local buffer, npending = { }, 0
      local function acc(x) table.insert(buffer, x) end
      for i = 1, #names  do
         local m = pmods and pmods[i]
         if m then
            if not m.optchain then
               acc ((']'):rep(npending))
               npending=0
            end
            if m.opt or m.optchain then acc('['); npending=npending+1 end
         end
         if i>1 then acc (', ') end
         acc(names[i])
      end
      acc ((']'):rep(npending))
      self.args = '('..table.concat(buffer)..')'
   end
end

function Item:type_of_param(p)
   local mods = self.modifiers[self.parameter]
   if not mods then return '' end
   local mparam = mods[p]
   return mparam and mparam.type or ''
end

function Item:type_of_ret(idx)
   local rparam = self.modifiers['return'][idx]
   return rparam and rparam.type or ''
end



function Item:warning(msg)
   local file = self.file and self.file.filename
   if type(file) == 'table' then pretty.dump(file); file = '?' end
   file = file or '?'
   io.stderr:write(file,':',self.lineno or '1',': ',self.name or '?',': ',msg,'\n')
   return nil
end

function Item:error(msg)
   self:warning(msg)
   os.exit(1)
end

Module.warning, Module.error = Item.warning, Item.error

function Module:hunt_for_reference (packmod, modules)
   local mod_ref
   local package = self.package or ''
   repeat -- same package?
      local nmod = package..'.'..packmod
      mod_ref = modules.by_name[nmod]
      if mod_ref then break end -- cool
      package = split_dotted_name(package)
   until not package
   return mod_ref
end

local function reference (s, mod_ref, item_ref)
   local name = item_ref and item_ref.name or ''
   -- this is deeply hacky; classes have 'Class ' prepended.
   if item_ref and item_ref.type == 'type' then
      name = 'Class_'..name
   end
   return {mod = mod_ref, name = name, label=s}
end

function Module:process_see_reference (s,modules)
   local mod_ref,fun_ref,name,packmod
   if not s:match '^[%w_%.%:%-]+$' or not s:match '[%w_]$' then
      return nil, "malformed see reference: '"..s..'"'
   end
   -- is this a fully qualified module name?
   local mod_ref = modules.by_name[s]
   if mod_ref then return reference(s, mod_ref,nil) end
   -- module reference?
   mod_ref = self:hunt_for_reference(s, modules)
   if mod_ref then return mod_ref end
   -- method reference? (These are of form CLASS.NAME)
   fun_ref = self.items.by_name[s]
   if fun_ref then return reference(s,self,fun_ref) end
   -- otherwise, start splitting!
   local packmod,name = split_dotted_name(s) -- e.g. 'pl.utils','split'
   if packmod then -- qualified name
      mod_ref = modules.by_name[packmod] -- fully qualified mod name?
      if not mod_ref then
         mod_ref = self:hunt_for_reference(packmod, modules)
         if not mod_ref then
            local ref = global.lua_manual_ref(s)
            if ref then return ref end
            return nil,"module not found: "..packmod
         end
      end
      fun_ref = mod_ref.items.by_name[name]
      if fun_ref then
         return reference(s,mod_ref,fun_ref)
      else
         fun_ref = mod_ref.sections.by_name[name]
         if not fun_ref then
            return nil,"function or section not found: "..s.." in "..mod_ref.name
         else
            return reference(fun_ref.name:gsub('_',' '),mod_ref,fun_ref)
         end
      end
   else -- plain jane name; module in this package, function in this module
      mod_ref = modules.by_name[self.package..'.'..s]
      if mod_ref then return reference(s, mod_ref,nil) end
      fun_ref = self.items.by_name[s]
      if fun_ref then return reference(s, self,fun_ref)
      else
         local ref = global.lua_manual_ref (s)
         if ref then return ref end
         return nil, "function not found: "..s.." in this module"
      end
   end
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
   for item in self.items:iter() do
      local see = item.tags.see
      if see then -- this guy has @see references
         item.see = List()
         for s in see:iter() do
            local href, err = self:process_see_reference(s,modules)
            if href then
               item.see:append (href)
               found:append{item,s}
            elseif err then
               item:warning(err)
            end
         end
      end
   end
   -- mark as found, so we don't waste time re-searching
   for f in found:iter() do
      f[1].tags.see:remove_value(f[2])
   end
end

-- suppress the display of local functions and annotations.
-- This is just a placeholder hack until we have a more general scheme
-- for indicating 'private' content of a module.
function Module:mask_locals ()
   self.kinds['Local Functions'] = nil
   self.kinds['Annotations'] = nil
end

function Item:dump_tags (taglist)
   for tag, value in pairs(self.tags) do
      if not taglist or taglist[tag] then
         Item.warning(self,tag..' '..tostring(value))
      end
   end
end

function Module:dump_tags (taglist)
   Item.dump_tags(self,taglist)
   for item in self.items:iter() do
      item:dump_tags(taglist)
   end
end

--------- dumping out modules and items -------------

function Module:dump(verbose)
   if self.type ~= 'module' then return end
   print '----'
   print(self.type..':',self.name,self.summary)
   if self.description then print(self.description) end
   for item in self.items:iter() do
      item:dump(verbose)
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
      if self.description and self.description:match '%S' then
         print 'description:'
         print(self.description)
      end
      if #self.params > 0 then
         print 'parameters:'
         for _,p in ipairs(self.params) do
            print('',p,self.params[p])
         end
      end
      if self.ret and #self.ret > 0 then
         print 'returns:'
         for _,r in ipairs(self.ret) do
            print('',r)
         end
      end
      if next(self.tags) then
         print 'tags:'
         for tag, value in pairs(self.tags) do
            print(tag,value)
         end
      end
   else
      print('* '..name..' - '..self.summary)
   end
end

function doc.filter_objects_through_function(filter, module_list)
   local quit, quote = utils.quit, tools.quote
   if filter == 'dump' then filter = 'pl.pretty.dump' end
   local mod,name = tools.split_dotted_name(filter)
   local ok,P = pcall(require,mod)
   if not ok then quit("cannot find module "..quote(mod)) end
   local ok,f = pcall(function() return P[name] end)
   if not ok or type(f) ~= 'function' then quit("dump module: no function "..quote(name)) end

   -- clean up some redundant and cyclical references--
   module_list.by_name = nil
   for mod in module_list:iter() do
      mod.kinds = nil
      mod.file = mod.file.filename
      for item in mod.items:iter() do
         item.module = nil
         item.file = nil
         item.formal_args = nil
         item.tags['return'] = nil
         item.see = nil
      end
      mod.items.by_name = nil
   end

   local ok,err = pcall(f,module_list)
   if not ok then quit("dump failed: "..err) end
end

return doc

