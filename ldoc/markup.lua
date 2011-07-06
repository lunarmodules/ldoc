--------------
-- Handling markup transformation.
-- Currently just does Markdown, but this is intended to
-- be the general module for managing other formats as well.

require 'pl'
local utils = require 'pl.utils'
local quit = utils.quit
local markup = {}

-- workaround Markdown's need for blank lines around indented blocks
-- (does mean you have to keep indentation discipline!)
function markup.insert_markdown_lines (txt)
   local res, append = {}, table.insert
   local last_indent, start_indent, skip = -1, -1, false
   for line in stringx.lines(txt) do
      if not line:match '^%s*$' then --ignore blank lines
         local indent = #line:match '^%s*'
         if start_indent < 0 then -- initialize indents at start
            start_indent = indent
            last_indent = indent
         end
         if indent < start_indent then -- end of indented block
            append(res,'')
            skip = false
         end
         if not skip and indent > last_indent then -- start of indent
            append(res,'')
            skip = true
            start_indent = indent
         end
         append(res,line)
         last_indent = indent
      else
         append(res,'')
      end
   end
   return table.concat(res,'\n')
end

-- inline <references> use same lookup as @see
function markup.resolve_inline_references (ldoc, txt)
   return (txt:gsub('<([%w_%.]-)>',function(name)
      local ref,err = ldoc.module:process_see_reference(name,ldoc.modules)
      if not ref then
         if ldoc.item then ldoc.item:warning(err)
         else io.stderr:write(err,'\n')
         end
         return ''
      end
      local label = ref.label:gsub('_','\\_')
      local res = ('<a href="%s">%s</a>'):format(ldoc.href(ref),label)
      return res
   end))
end

function markup.create (ldoc, format)
   if format == 'plain' then
      return function(txt)
         if txt == nil then return '' end
         return markup.resolve_inline_references(ldoc, txt)
      end
   else
      local ok,formatter = pcall(require,format)
      if not ok then quit("cannot load formatter: "..format) end
      return function (txt)
         if txt == nil then return '' end
         txt = markup.resolve_inline_references(ldoc, txt)
         if txt:find '\n' and not ldoc.classic_markdown then -- multiline text
            txt = markup.insert_markdown_lines(txt)
         end
         txt = formatter   (txt)
         -- We will add our own paragraph tags, if needed.
         return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
      end
   end
end


return markup
