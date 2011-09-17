--------------
-- Handling markup transformation.
-- Currently just does Markdown, but this is intended to
-- be the general module for managing other formats as well.

require 'pl'
local doc = require 'ldoc.doc'
local utils = require 'pl.utils'
local prettify = require 'ldoc.prettify'
local quit, concat, lstrip = utils.quit, table.concat, stringx.lstrip
local markup = {}

-- workaround Markdown's need for blank lines around indented blocks
-- (does mean you have to keep indentation discipline!)
function markup.insert_markdown_lines (txt)
   local res, append = {}, table.insert
   local last_indent, start_indent, skip, code = -1, -1, false, nil
   for line in stringx.lines(txt) do
      line = line:gsub('\t','    ')  -- some people like tabs ;)
      if not line:match '^%s*$' then --ignore blank lines
         local indent = #line:match '^%s*'
         if start_indent < 0 then -- initialize indents at start
            start_indent = indent
            last_indent = indent
         end
         if indent < start_indent then -- end of indented block
            append(res,'')
            skip = false
            if code then
               code = concat(code,'\n')
               code, err = prettify.lua(code)
               if code then
                  append(res,code)
                  append(res,'</pre>')
               end
               code = nil
            end
         end
         if not skip and indent > last_indent then -- start of indent
            append(res,'')
            skip = true
            start_indent = indent
            if indent >= 4 then
               code = {}
            end
         end
         if code then
            append(code, line:sub(start_indent))
         else
            append(res,line)
         end
         last_indent = indent
      elseif not code then
         append(res,'')
      end
   end
   res = concat(res,'\n')
   return res
end

-- inline <references> use same lookup as @see
local function resolve_inline_references (ldoc, txt, item)
   return (txt:gsub('@{([^}]-)}',function (name)
      local qname,label = utils.splitv(name,'%s*|')
      if not qname then
         qname = name
      end
      local ref,err = markup.process_reference(qname)
      if not ref then
         err = err .. ' ' .. qname
         if item then item:warning(err)
         else
           io.stderr:write('nofile error: ',err,'\n')
         end
         return '???'
      end
      if not label then
         label = ref.label
      end
      if not markup.plain then -- a nastiness with markdown.lua and underscores
         label = label:gsub('_','\\_')
      end
      local res = ('<a href="%s">%s</a>'):format(ldoc.href(ref),label)
      return res
   end))
end

-- for readme text, the idea here is to create module sections at ## so that
-- they can appear in the contents list as a ToC.
function markup.add_sections(F, txt)
   local sections, L = {}, 1
   for line in stringx.lines(txt) do
      local title = line:match '^##[^#]%s*(.+)'
      if title then
         sections[L] = F:add_document_section(title)
      end
      L = L + 1
   end
   F.sections = sections
   return txt
end

local function process_multiline_markdown(ldoc, txt, F)
   local res, L, append = {}, 1, table.insert
   local err_item = {
      warning = function (self,msg)
         io.stderr:write(F.filename..':'..L..': '..msg,'\n')
      end
   }
   for line in stringx.lines(txt) do
      line = resolve_inline_references(ldoc, line, err_item)
      local section = F.sections[L]
      if section then
         append(res,('<a name="%s"></a>'):format(section))
      end
      append(res,line)
      L = L + 1
   end
   return concat(res,'\n')
end


function markup.create (ldoc, format)
   local processor
   markup.plain = true
   markup.process_reference = function(name)
      local mod = ldoc.single or ldoc.module
      return mod:process_see_reference(name, ldoc.modules)
   end
   markup.href = function(ref)
      return ldoc.href(ref)
   end

   if format == 'plain' then
      processor = function(txt, item)
         if txt == nil then return '' end
         return resolve_inline_references(ldoc, txt, item)
      end
   else
      local ok,formatter = pcall(require,format)
      if not ok then quit("cannot load formatter: "..format) end
      markup.plain = false
      processor = function (txt,item)
         if txt == nil then return '' end
         if utils.is_type(item,doc.File) then
            txt = process_multiline_markdown(ldoc, txt, item)
         else
            txt = resolve_inline_references(ldoc, txt, item)
         end
         if txt:find '\n' and ldoc.extended_markdown then -- multiline text
            txt = markup.insert_markdown_lines(txt)
         end
         txt = formatter(txt)
         -- We will add our own paragraph tags, if needed.
         return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
      end
   end
   markup.resolve_inline_references = function(txt, errfn)
      return resolve_inline_references(ldoc, txt, errfn)
   end
   markup.processor = processor
   prettify.resolve_inline_references = markup.resolve_inline_references
   return processor
end


return markup
