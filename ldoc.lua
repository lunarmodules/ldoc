---------------
-- ldoc, a Lua documentation generator.
-- Compatible with luadoc-style annoations, but providing
-- easier customization options. C/C++ support is provided.
-- Steve Donovan, 2011

require 'pl'

local append = table.insert
local template = require 'pl.template'
local lapp = require 'pl.lapp'

-- so we can find our private modules
app.require_here()

local args = lapp [[
ldoc, a documentation generator for Lua, vs 0.5
  -d,--dir (default docs) output directory
  -o,--output  (default 'index') output name
  -v,--verbose          verbose
  -a,--all              show local functions, etc, in docs
  -q,--quiet            suppress output
  -m,--module           module docs as text
  -s,--style (default !) directory for style sheet (ldoc.css)
  -l,--template (default !) directory for template (ldoc.ltp)
  -1,--one              use one-column output layout
  -p,--project (default ldoc) project name
  -t,--title (default Reference) page title
  -f,--format (default plain) formatting - can be markdown or plain
  -b,--package  (default .) top-level package basename (needed for module(...))
  -x,--ext (default html) output file extension
  -c,--config (default config.ld) configuration name
  --dump                debug output dump
  --filter (default none) filter output as Lua data (e.g pl.pretty.dump)
  <file> (string) source file or directory containing source
]]

local lexer = require 'ldoc.lexer'
local doc = require 'ldoc.doc'
local lang = require 'ldoc.lang'
local Item,File,Module = doc.Item,doc.File,doc.Module
local tools = require 'ldoc.tools'
local global = require 'builtin.globals'
local markup = require 'ldoc.markup'
local KindMap = tools.KindMap

class.ModuleMap(KindMap)

function ModuleMap:_init ()
   self.klass = ModuleMap
   self.fieldname = 'section'
end

ModuleMap:add_kind('function','Functions','Parameters')
ModuleMap:add_kind('table','Tables','Fields')
ModuleMap:add_kind('field','Fields')
ModuleMap:add_kind('lfunction','Local Functions','Parameters')


class.ProjectMap(KindMap)
ProjectMap.project_level = true

function ProjectMap:_init ()
   self.klass = ProjectMap
   self.fieldname = 'type'
end

ProjectMap:add_kind('module','Modules')
ProjectMap:add_kind('script','Scripts')
ProjectMap:add_kind('topic','Topics')
ProjectMap:add_kind('example','Examples')


------- ldoc external API ------------

-- the ldoc table represents the API available in `config.ld`.
local ldoc = {}
local add_language_extension

-- aliases to existing tags can be defined. E.g. just 'p' for 'param'
function ldoc.alias (a,tag)
   doc.add_alias(a,tag)
end

function ldoc.add_language_extension(ext,lang)
   add_language_extension(ext,lang)
end

function ldoc.add_section (name,title,subname)
   ModuleMap:add_kind(name,title,subname)
end

-- new tags can be added, which can be on a project level.
function ldoc.new_type (tag,header,project_level)
   doc.add_tag(tag,doc.TAG_TYPE,project_level)
   if project_level then
      ProjectMap:add_kind(tag,header)
   else
      ModuleMap:add_kind(tag,header)
   end
end

-- any file called 'config.ld' found in the source tree will be
-- handled specially. It will be loaded using 'ldoc' as the environment.
local function read_ldoc_config (fname)
   local directory = path.dirname(fname)
   local err
   print('reading configuration from '..fname)
   local txt,not_found = utils.readfile(fname)
   if txt then
       -- Penlight defines loadin for Lua 5.1 as well
      local chunk,err
      if not loadin then -- Penlight 0.9.5
         chunk,err = load(txt,nil,nil,ldoc)
      else
         chunk,err = loadin(ldoc,txt)
      end
      if chunk then
         local ok
         ok,err = pcall(chunk)
       end
    end
   if err then print('error loading config file '..fname..': '..err) end
   return directory, not_found
end

local function quote (s)
   return "'"..s.."'"
end

------ Parsing the Source --------------
-- This uses the lexer from PL, but it should be possible to use Peter Odding's
-- excellent Lpeg based lexer instead.

local tnext = lexer.skipws

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

local quit = utils.quit


-- parses a Lua or C file, looking for ldoc comments. These are like LuaDoc comments;
-- they start with multiple '-'. (Block commments are allowed)
-- If they don't define a name tag, then by default
-- it is assumed that a function definition follows. If it is the first comment
-- encountered, then ldoc looks for a call to module() to find the name of the
-- module if there isn't an explicit module name specified.

local function parse_file(fname,lang)
   local line,f = 1
   local F = File(fname)
   local module_found, first_comment = false,true

   local tok,f = lang.lexer(fname)
   local toks = tools.space_skip_getter(tok)

    function lineno ()
        while true do
            local res = lexer.lineno(tok)
            if type(res) == 'number' then return res end
            if res == nil then return nil end
        end
    end
   function filename () return fname end

   function F:warning (msg,kind)
      kind = kind or 'warning'
      lineno() -- why is this necessary?
      lineno()
      io.stderr:write(kind..' '..fname..':'..lineno()..' '..msg,'\n')
   end

   function F:error (msg)
      self:warning(msg,'error')
      os.exit(1)
   end

   local function add_module(tags,module_found,old_style)
      tags.name = module_found
      tags.class = 'module'
      local item = F:new_item(tags,lineno())
      item.old_style = old_style
   end

   local t,v = tok()
   while t do
      if t == 'comment' then
         local comment = {}
         local ldoc_comment,block = lang:start_comment(v)
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

         local fun_follows, tags, is_local
         if ldoc_comment or first_comment then
            comment = table.concat(comment)
            if not ldoc_comment and first_comment then
               F:warning("first comment must be a doc comment!")
               break
            end
            first_comment = false
            fun_follows, is_local = lang:function_follows(t,v,tok)
            if fun_follows or comment:find '@'then
               tags = extract_tags(comment)
               if doc.project_level(tags.class) then
                  module_found = tags.name
               end
               if tags.class == 'function' then
                  fun_follows, is_local = false, false
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
               if not t then quit(fname..": end of file") end -- run out of file!
               -- we have to guess the module name
               module_found = tools.this_module_name(args.package,fname)
            end
            if not tags then tags = extract_tags(comment) end
            add_module(tags,module_found,old_style)
            tags = nil
            -- if we did bump into a doc comment, then we can continue parsing it
         end

         -- end of a block of document comments
         if ldoc_comment and tags then
            local line = t ~= nil and lineno() or 666
            if t ~= nil then
               if fun_follows then -- parse the function definition
                  lang:parse_function_header(tags,tok,toks)
               else
                  lang:parse_extra(tags,tok,toks)
               end
            end
            -- local functions treated specially
            if tags.class == 'function' and (is_local or tags['local']) then
               tags.class = 'lfunction'
            end
            if tags.name then
               F:new_item(tags,line).inferred = fun_follows
            end
            if not t then break end
         end
      end
      if t ~= 'comment' then t,v = tok() end
   end
   if f then f:close() end
   return F
end

function read_file(name,lang)
   local F = parse_file(name,lang)
   F:finish()
   return F
end

--- processing command line and preparing for output ---

local F
local file_list,module_list = List(),List()
module_list.by_name = {}
local config_dir


local ldoc_dir = arg[0]:gsub('[^/\\]+$','')
local doc_path = ldoc_dir..'builtin/?.luadoc'


-- ldoc -m is expecting a Lua package; this converts this to a file path
if args.module then
   -- first check if we've been given a global Lua lib function
   if args.file:match '^%a+$' and global.functions[args.file] then
      args.file = 'global.'..args.file
   end
   local fullpath,mod = tools.lookup_existing_module_or_function (args.file, doc_path)
   if not fullpath then
      quit(mod)
   else
      args.file = fullpath
      args.module = mod
   end
end

-- a special case: 'ldoc .' can get all its parameters from config.ld
if args.file == '.' then
   local err
   config_dir,err = read_ldoc_config('./'..args.config)
   if err then quit("no "..quote(args.config).." found here") end
   config_is_read = true
   args.file = ldoc.file or '.'
   if args.file == '.' then
      args.file = lfs.currentdir()
   elseif type(args.file) == 'table' then
      for i,f in ipairs(args.file) do
         args.file[i] = path.abspath(f)
         print(args.file[i])
      end
   else
      args.file = path.abspath(args.file)
   end
else
   args.file = path.abspath(args.file)
end

local source_dir = args.file
if type(args.file) == 'string' and path.isfile(args.file) then
   source_dir = path.splitpath(source_dir)
end

---------- specifying the package for inferring module names --------
-- If you use module(...), or forget to explicitly use @module, then
-- ldoc has to infer the module name. There are three sensible values for
-- `args.package`:
--
--  * '.' the actual source is in an immediate subdir of the path given
--  * '..' the path given points to the source directory
--  * 'NAME' explicitly give the base module package name
--

local function setup_package_base()
   if ldoc.package then args.package = ldoc.package end
   if args.package == '.' then
      args.package = source_dir
   elseif args.package == '..' then
      args.package = path.splitpath(source_dir)
   elseif not args.package:find '[\//]' then
      local subdir,dir = path.splitpath(source_dir)
      if dir == args.package then
         args.package = subdir
      elseif path.isdir(path.join(source_dir,args.package)) then
         args.package = source_dir
      else
         quit("args.package is not the name of the source directory")
      end
   end
end

local lua, cc = lang.lua, lang.cc

local file_types = {
   ['.lua'] = lua,
   ['.ldoc'] = lua,
   ['.luadoc'] = lua,
   ['.c'] = cc,
   ['.cpp'] = cc,
   ['.cxx'] = cc,
   ['.C'] = cc
}

function add_language_extension (ext,lang)
   lang = (lang=='c' and cc) or (lang=='lua' and lua) or quit('unknown language')
   if ext:sub(1,1) ~= '.' then ext = '.'..ext end
   file_types[ext] = lang
end

--------- processing files ---------------------
-- ldoc may be given a file, or a directory. `args.file` may also be specified in config.ld
-- where it is a list of files or directories. If specified on the command-line, we have
-- to find an optional associated config.ld, if not already loaded.

local function process_file (f, file_list)
   local ext = path.extension(f)
   local ftype = file_types[ext]
   if ftype then
      if args.verbose then print(path.basename(f)) end
      local F = read_file(f,ftype)
      file_list:append(F)
   end
end

local process_file_list = tools.process_file_list

if type(args.file) == 'table' then
   -- this can only be set from config file so we can assume it's already read
   process_file_list(args.file,'*.*',process_file, file_list)
   if #file_list == 0 then quit "no source files specified" end
elseif path.isdir(args.file) then
   local files = List(dir.getallfiles(args.file,'*.*'))
   -- use any configuration file we find, if not already specified
   if not config_dir then
      local config_files = files:filter(function(f)
         return path.basename(f) == args.config
      end)
      if #config_files > 0 then
         config_dir = read_ldoc_config(config_files[1])
         if #config_files > 1 then
            print('warning: other config files found: '..config_files[2])
         end
      end
   end
   for f in files:iter() do
      process_file(f, file_list)
   end
   if #file_list == 0 then
      quit(quote(args.file).." contained no source files")
   end
elseif path.isfile(args.file) then
   -- a single file may be accompanied by a config.ld in the same dir
   if not config_dir then
      config_dir = path.dirname(args.file)
      if config_dir == '' then config_dir = '.' end
      local config = path.join(config_dir,args.config)
      if path.isfile(config) then
         read_ldoc_config(config)
      end
   end
   process_file(args.file, file_list)
   if #file_list == 0 then quit "unsupported file extension" end
else
   quit ("file or directory does not exist: "..quote(args.file))
end

setup_package_base()


local multiple_files = #file_list > 1
local first_module

------ 'Special' Project-level entities ---------------------------------------
-- Examples and Topics do not contain code to be processed for doc comments.
-- Instead, they are intended to be rendered nicely as-is, whether as pretty-lua
-- or as Markdown text. Treating them as 'modules' does stretch the meaning of
-- of the term, but allows them to be treated much as modules or scripts.
-- They define an item 'body' field (containing the file's text) and a 'postprocess'
-- field which is used later to convert them into HTML. They may contain @{ref}s.

local function add_special_project_entity (f,tags,process)
   local F = File(f)
   tags.name = path.basename(f)
   local text = utils.readfile(f)
   local item = F:new_item(tags,1)
   if process then
      text = process(F, text)
   end
   F:finish()
   file_list:append(F)
   item.body = text
   return item
end

if type(ldoc.examples) == 'table' then
   local prettify = require 'ldoc.prettify'

   local function process_example (f, file_list)
      local item = add_special_project_entity(f,{
         class = 'example',
      })
      item.postprocess = prettify.lua
   end

   process_file_list (ldoc.examples, '*.lua', process_example, file_list)
end

if type(ldoc.readme) == 'string' then
   local item = add_special_project_entity(ldoc.readme,{
      class = 'topic'
   }, markup.add_sections)
   item.postprocess = markup.create(ldoc, 'markdown')
end

---- extract modules from the file objects, resolve references and sort appropriately ---

local project = ProjectMap()

for F in file_list:iter() do
   for mod in F.modules:iter() do
      if not first_module then first_module = mod end
      module_list:append(mod)
      module_list.by_name[mod.name] = mod
   end
end

for mod in module_list:iter() do
   mod:resolve_references(module_list)
   project:add(mod,module_list)
end

-- the default is not to show local functions in the documentation.
if not args.all then
   for mod in module_list:iter() do
      mod:mask_locals()
   end
end

table.sort(module_list,function(m1,m2)
   return m1.name < m2.name
end)

-------- three ways to dump the object graph after processing -----

-- ldoc -m will give a quick & dirty dump of the module's documentation;
-- using -v will make it more verbose
if args.module then
   if #module_list == 0 then quit("no modules found") end
   if args.module == true then
      file_list[1]:dump(args.verbose)
   else
      local fun = module_list[1].items.by_name[args.module]
      if not fun then quit(quote(args.module).." is not part of "..quote(args.file)) end
      fun:dump(true)
   end
   return
end

-- ldoc --dump will do the same as -m, except for the currently specified files
if args.dump then
   for mod in module_list:iter() do
      mod:dump(true)
   end
   os.exit()
end

-- ldoc --filter mod.name will load the module `mod` and pass the object graph
-- to the function `name`. As a special case --filter dump will use pl.pretty.dump.
if args.filter ~= 'none' then
   doc.filter_objects_through_function(args.filter, module_list)
   os.exit()
end

local css, templ = 'ldoc.css','ldoc.ltp'

local function style_dir (sname)
   local style = ldoc[sname]
   local dir
   if style then
      if style == true then
         dir = config_dir
      elseif type(style) == 'string' and path.isdir(style) then
         dir = style
      else
         quit(quote(tostring(name)).." is not a directory")
      end
      args[sname] = dir
   end
end

local function override (field)
   if ldoc[field] then args[field] = ldoc[field] end
end

-- the directories for template and stylesheet can be specified
-- either by command-line '--template','--style' arguments or by 'template and
-- 'style' fields in config.ld.
-- The assumption here is that if these variables are simply true then the directory
-- containing config.ld contains a ldoc.css and a ldoc.ltp respectively. Otherwise
-- they must be a valid subdirectory.

style_dir 'style'
style_dir 'template'

-- can specify format, output, dir and ext in config.ld
override 'format'
override 'output'
override 'dir'
override 'ext'
override 'one'

if not args.ext:find '^%.' then
   args.ext = '.'..args.ext
end

if args.one then
   css = 'ldoc_one.css'
end

-- '!' here means 'use same directory as ldoc.lua
local ldoc_html = path.join(ldoc_dir,'html')
if args.style == '!' then args.style = ldoc_html end
if args.template == '!' then args.template = ldoc_html end

local module_template,err = utils.readfile (path.join(args.template,templ))
if not module_template then
   quit("template not found. Use -l to specify directory containing ldoc.ltp")
end

-- create the function that renders text (descriptions and summaries)
ldoc.markup = markup.create(ldoc, args.format)

-- this generates the internal module/function references; strictly speaking,
-- it should be (and was) part of the template, but inline references in
-- Markdown required it be more widely available. A temporary situation!

function ldoc.href(see)
   if see.href then -- explict reference, e.g. to Lua manual
      return see.href
   else
      return ldoc.ref_to_module(see.mod)..'#'..see.name
   end
end

-- this is either called from the 'root' (index or single module) or
-- from the 'modules' etc directories. If we are in one of those directories,
-- then linking to another kind is `../kind/name`; to the same kind is just `name`.
-- If we are in the root, then it is `kind/name`.

function ldoc.ref_to_module (mod)
   local base = "" -- default: same directory
   local kind, module = mod.kind, ldoc.module
   local name = mod.name -- default: name of module
   if not ldoc.single then
      if module then -- we are in kind/
         if module.type ~= type then -- cross ref to ../kind/
            base = "../"..kind.."/"
         end
      else -- we are in root: index
         base = kind..'/'
      end
   else -- single module
      if mod == first_module then
         name = ldoc.output
         if not ldoc.root then base = '../' end
      elseif ldoc.root then -- ref to other kinds (like examples)
         base = kind..'/'
      else
         if module.type ~= type then -- cross ref to ../kind/
            base = "../"..kind.."/"
         end
      end
   end
   return base..name..'.html'
end


local function generate_output()
   local check_directory, check_file, writefile = tools.check_directory, tools.check_file, tools.writefile
   ldoc.single = not multiple_files and first_module or nil
   ldoc.log = print
   ldoc.kinds = project
   ldoc.css = css
   ldoc.modules = module_list
   ldoc.title = ldoc.title or args.title
   ldoc.project = ldoc.project or args.project

   -- in single mode there is one module and the 'index' is the
   -- documentation for that module.
   ldoc.module = ldoc.single and first_module or nil
   ldoc.root = true
   local out,err = template.substitute(module_template,{
      ldoc = ldoc,
      module = ldoc.module
    })
   ldoc.root = false
   if not out then quit("template failed: "..err) end

   check_directory(args.dir) -- make sure output directory is ok

   args.dir = args.dir .. path.sep

   check_file(args.dir..css, path.join(args.style,css)) -- has CSS been copied?

   -- write out the module index
   writefile(args.dir..args.output..args.ext,out)

   -- write out the per-module documentation
   -- in single mode, we exclude any modules since the module has been done;
   -- this step is then only for putting out any examples or topics
   ldoc.css = '../'..css
   ldoc.output = args.output
   for kind, modules in project() do
      kind = kind:lower()
      if not ldoc.single or ldoc.single and kind ~= 'modules' then
         check_directory(args.dir..kind)
         for m in modules() do
            ldoc.module = m
            ldoc.body = m.body
            if ldoc.body then
               ldoc.body = m.postprocess(ldoc.body)
            end
            out,err = template.substitute(module_template,{
               module=m,
               ldoc = ldoc
            })
            if not out then
               quit('template failed for '..m.name..': '..err)
            else
               writefile(args.dir..kind..'/'..m.name..args.ext,out)
            end
         end
      end
   end
   if not args.quiet then print('output written to '..args.dir) end
end

generate_output()

if args.verbose then
   print 'modules'
   for k in pairs(module_list.by_name) do print(k) end
end


