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

-- for readme text, the idea here is to insert module sections at ## so that
-- they can appear in the contents list as a ToC
function markup.add_sections(F, txt)
   local res, append = {}, table.insert
   for line in stringx.lines(txt) do
      local title = line:match '^##[^#]%s*(.+)'
      if title then
         local section = F:add_document_section(title)
         append(res,('<a id="%s"></a>\n'):format(section))
         append(res,line)
      else
         append(res,line)
      end
   end
   return concat(res,'\n')
end

local function handle_reference (ldoc, name)
   local ref,err = markup.process_reference(name)
   if not ref then
      if ldoc.item then ldoc.item:warning(err)
      else
        io.stderr:write(err,'\n')
      end
      return ''
   end
   local label = ref.label
   if not ldoc.plain then -- a nastiness with markdown.lua and underscores
      label = label:gsub('_','\\_')
   end
   local res = ('<a href="%s">%s</a>'):format(ldoc.href(ref),label)
   return res
end

local ldoc_handle_reference

-- inline <references> use same lookup as @see
local function resolve_inline_references (ldoc, txt)
   return (txt:gsub('@{([%w_%.%-]-)}',ldoc_handle_reference))
end

function markup.create (ldoc, format)
   local processor
   ldoc_handle_reference = utils.bind1(handle_reference,ldoc)
   markup.plain = true
   markup.process_reference = function(name)
      local mod = ldoc.single or ldoc.module
      return mod:process_see_reference(name, ldoc.modules)
   end
   markup.href = function(ref)
      return ldoc.href(ref)
   end

   if format == 'plain' then
      processor = function(txt)
         if txt == nil then return '' end
         return resolve_inline_references(ldoc, txt)
      end
   else
      local ok,formatter = pcall(require,format)
      if not ok then quit("cannot load formatter: "..format) end
      markup.plain = false
      processor = function (txt)
         if txt == nil then return '' end
         txt = resolve_inline_references(ldoc, txt)
         if txt:find '\n' and not ldoc.classic_markdown then -- multiline text
            txt = markup.insert_markdown_lines(txt)
         end
         txt = formatter   (txt)
         -- We will add our own paragraph tags, if needed.
         return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
      end
   end
   markup.resolve_inline_references = function(txt)
      return resolve_inline_references(ldoc, txt)
   end
   markup.processor = processor
   prettify.resolve_inline_references = markup.resolve_inline_references
   return processor
end


return markup
