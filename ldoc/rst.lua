------ generating RST output ---------
-- Although this can be generalized for outputting any format, since the template
-- is language-agnostic, this implementation concentrates on HTML.
-- This does the actual generation of HTML, and provides support functions in the ldoc
-- table for the template
--
-- A fair amount of the complexity comes from operating in two basic modes; first, where
-- there is a number of modules (classic LuaDoc) or otherwise, where there is only one
-- module and the index contains the documentation for that module.
--
-- Like LuaDoc, LDoc puts similar kinds of documentation files in their own directories.
-- So module docs go into 'modules/', scripts go into 'scripts/', and so forth. LDoc
-- generalizes the idea of these project-level categories and in fact custom categories
-- can be created (refered to as 'kinds' in the code)

local List = require 'pl.List'
local utils = require 'pl.utils'
local path = require 'pl.path'
local stringx = require 'pl.stringx'
local template = require 'pl.template'
local tablex = require 'pl.tablex'
local OrderedMap = require 'pl.OrderedMap'
local tools = require 'ldoc.tools'
local markup = require 'ldoc.markup'
local prettify = require 'ldoc.prettify'
local doc = require 'ldoc.doc'
local pretty = require 'pl.pretty'
local unpack = utils.unpack
local rst = {}


local quit = utils.quit

local function cleanup_whitespaces(text)
   local lines = stringx.splitlines(text)
   for i = 1, #lines do
      --print(lines)
      --lines[i] = stringx.rstrip(lines[i])
   end
   lines[#lines + 1] = "" -- Little trick: file should end with newline
   return table.concat(lines, "\n")
end

local function get_module_info(m)
   local info = OrderedMap()
   for tag in doc.module_info_tags() do
      local val = m.tags[tag]
      if type(val)=='table' then
         val = table.concat(val,',')
      end
      tag = stringx.title(tag)
      info:set(tag,val)
   end
   if #info:keys() > 0 then
      return info
   end
end

local function md_2_rst(text)
   for header, sign in pairs({["^#"] = "=", ["\n#"] = "=", ["\n##"] = "-", ["\n###"] = "~"}) do
      text = text:gsub(""..header.." (.-)[\r\n]", "\n" .. string.rep(sign, 79).."\n%1\n" .. string.rep(sign, 79) .. "\n\n")
   end
   local function tab_block(code_block)
      return code_block:gsub("\n", "\n    ")
   end

   for code_lang in List {"lua", "yaml", "bash"}:iter() do
      text = text:gsub("```("..code_lang..")(.-)```",
              function(lang, code) return "\n.. code-block:: "..lang.." \n"..tab_block(code).."\n" end)
   end

   local function inline_link(label, link)
      label = label:match("%b[]"):sub(2,-2)
      local url, title = link:match("%(<?(.-)>?[ \t]*['\"](.+)['\"]")
      url  = url or  link:match("%(<?(.-)>?%)") or ""
      return ('`%s <%s>`_'):format(label, url)
   end

   text = text:gsub("(%b[])(%b())", inline_link)

   return text
end

local escape_table = { ["'"] = "&apos;", ["\""] = "&quot;", ["&"] = "&amp;" }

function rst.generate_output(ldoc, args, project)
   local check_directory, check_file, writefile = tools.check_directory, tools.check_file, tools.writefile
   local original_ldoc

   local function save_and_set_ldoc (set)
      if not set then return end
      if not original_ldoc then
         original_ldoc = tablex.copy(ldoc)
      end
      for s in set:iter() do
         local var,val = s:match('([^=]+)=(.+)')
         local num = tonumber(val)
         if num then val = num
         elseif val == 'true' then val = true
         elseif val == 'false' then val = false
         end
         print('setting',var,val)
         ldoc[var] = val
      end
   end

   local function restore_ldoc ()
      if original_ldoc then
         ldoc = original_ldoc
      end
   end

   function ldoc.escape(str)
      return (str:gsub("['`&<>\"]", escape_table))
   end

   local function indent(text)
      return text:gsub('\n', '\n    ')
   end

   local function lua_code_block(text)
      return ".. code-block:: lua\n\n    "..text
   end

   function ldoc.prettify(str)
      if ldoc.rst == true then
         return lua_code_block(indent(str))
      else
         return prettify.code('lua','usage',str,0,false)
      end
   end

   -- Item descriptions come from combining the summary and description fields
   function ldoc.descript(item)
      return tools.join(' ', item.summary, item.description)
   end

   function ldoc.module_name (mod)
      local name = mod.name
      if args.unqualified and (mod.type == 'module' or mod.type == 'classmod') then -- leave out package
         name = name:gsub('^.-%.','')
      elseif mod.type == 'topic' then
         if mod.display_name then
            name = mod.display_name
         else -- leave out md extension
            name = name:gsub('%..*$','')
         end
      end
      return name
   end

   -- this generates the internal module/function references
   function ldoc.href(see)
      if see.href then -- explict reference, e.g. to Lua manual
         return see.href
      elseif doc.Module:class_of(see) then
         return ldoc.ref_to_module(see)..'_'
      elseif see.name ~= '' then
         return ldoc.ref_to_module(see.mod)..'.'..see.name
      else
         return ldoc.ref_to_module(see.mod)
      end
   end

   function ldoc.ref_to_module (mod)
      return mod.name
   end

   function ldoc.include_file (file)
      local text,e = utils.readfile(file)
      if not text then quit("unable to include "..file)
      else
         return text
      end
   end

   -- these references are never from the index...?
   function ldoc.source_ref (fun)
      local modname = fun.module.name
      local pack,name = tools.split_dotted_name(modname)
      if not pack then
         name = modname
      end
      return (ldoc.single and "" or "../").."source/"..name..'.lua.html#'..fun.lineno
   end

   function ldoc.default_display_name(item)
      -- Project-level items:
      if doc.project_level(item.type) then
        return ldoc.module_name(item)
      end
      -- Module-level items:
      local name = item.display_name or item.name
      if item.type == 'function' or item.type == 'lfunction' then
         if not ldoc.no_space_before_args then
            name = name..' '
         end
         return name..item.args
      else
         return name
      end
   end

   function ldoc.display_name(item)
      if ldoc.custom_display_name_handler then
        return ldoc.custom_display_name_handler(item, ldoc.default_display_name)
      else
        return ldoc.default_display_name(item)
      end
   end

   function ldoc.no_spaces(s)
      s = s:gsub('%s*$','')
      return (s:gsub('%W','_'))
   end

   function ldoc.module_typename(m)
      return doc.presentation_name(m.type)
   end

   function ldoc.is_list (t)
      return type(t) == 'table' and t.append
   end

   function ldoc.strip_header (s)
      if not s then return s end
      return s:gsub('^%s*#+%s+','')
   end

   function ldoc.typename (tp)
      if not tp or tp == '' or tp:match '^@' then return '' end
      local optional
      -- ?<type> is short for ?nil|<type>
      if tp:match("^%?") and not tp:match '|' then
         tp = '?|'..tp:sub(2)
      end
      local tp2 = tp:match("%?|?(.*)")
      if tp2 then
         optional = true
         tp = tp2
      end

      local types = {}
      for name in tp:gmatch("[^|]+") do
         local sym = name:match '([%w%.%:]+)'
         local ref,err = markup.process_reference(sym,true)
         if ref then
            if ref.label and sym == name then
               name = ref.label
            end
            local link_template = '`%s <%s_>`_'
            if ref.href then link_template = '`%s <%s>`_' end
            types[#types+1] = (link_template):format(name, ldoc.href(ref))
         else
            types[#types+1] = '**'..name..'**'
         end
      end
      local names = table.concat(types, ", ", 1, math.max(#types-1, 1))
      if #types > 1 then names = names.." or "..types[#types] end
      if optional then
         if names ~= '' then
            if #types == 1 then names = "optional "..names end
         else
            names = "optional"
        end
      end
      return '('..names..')'
   end

   -- the somewhat tangled logic that controls whether a type appears in the
   -- navigation sidebar. (At least it's no longer in the template ;))
   function ldoc.allowed_in_contents(type,module)
      local allowed = true
      if ldoc.kinds_allowed then
         allowed = ldoc.kinds_allowed[type]
      elseif ldoc.prettify_files and type == 'file' then
         allowed = ldoc.prettify_files == 'show' or (module and module.type == 'file')
      end
      return allowed
   end

   local function set_charset (ldoc,m)
      m = m or ldoc.module
      ldoc.doc_charset = (m and m.tags.charset) or ldoc.charset
   end

   local module_template,err = utils.readfile (path.join(args.template,ldoc.templ))
   if not module_template then
      quit("template not found at '"..args.template.."' Use -l to specify directory containing ldoc.ltp")
   end

   -- Runs a template on a module to generate HTML page.
   local function templatize(template_str, ldoc, module)
      local out, err = template.substitute(template_str, {
         ldoc = ldoc,
         module = module,
         _escape = ldoc.template_escape
      })
      if not out then
         quit(("template failed for %s: %s"):format(
               module and module.name or ldoc.output or "index",
               err))
      end
      return cleanup_whitespaces(out)
   end

   ldoc.output = args.output
   ldoc.ipairs = ipairs
   ldoc.pairs = pairs
   ldoc.print = print

   -- Bang out the index.
   -- in single mode there is one module and the 'index' is the
   -- documentation for that module.
   ldoc.module = ldoc.single
   if ldoc.single and args.one then
      ldoc.kinds_allowed = {module = true, topic = true}
      ldoc.one = true
   end
   ldoc.root = true
   if ldoc.module then
      ldoc.module.info = get_module_info(ldoc.module)
      ldoc.module.ldoc = ldoc
      save_and_set_ldoc(ldoc.module.tags.set)
   end
   set_charset(ldoc)
   local out = templatize(module_template, ldoc, ldoc.module)
   ldoc.root = false
   restore_ldoc()

   check_directory(args.dir) -- make sure output directory is ok

   args.dir = args.dir .. path.sep

   -- write out the module index
   out = cleanup_whitespaces(out)
   writefile(args.dir..args.output..args.ext,out)

   -- in single mode, we exclude any modules since the module has been done;
   -- ext step is then only for putting out any examples or topics
   local mods = List()
   for kind, modules in project() do
      local lkind = kind:lower()
      if not ldoc.single or ldoc.single and lkind ~= 'modules' then
         mods:append {kind, lkind, modules}
      end
   end

   -- write out the per-module documentation
   -- note that we reset the internal ordering of the 'kinds' so that
   -- e.g. when reading a topic the other Topics will be listed first.
   for m in mods:iter() do
      local kind, lkind, modules = unpack(m)
      check_directory(args.dir..lkind)
      project:put_kind_first(kind)
      for m in modules() do
         ldoc.module = m
         ldoc.body = m.body
         m.ldoc = ldoc
         if m.tags.set then
            save_and_set_ldoc(m.tags.set)
         end
         set_charset(ldoc)
         m.info = get_module_info(m)
         if ldoc.body and m.postprocess then
            ldoc.body = md_2_rst(ldoc.body)
         end
         local out = templatize(module_template, ldoc, m)
         writefile(args.dir..lkind..'/'..m.name..args.ext,out)
         restore_ldoc()
      end
   end
   if not args.quiet then print('output written to '..tools.abspath(args.dir)) end
end

return rst

