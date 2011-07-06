--------------
-- Handling markup transformation.
-- Currently just does Markdown, but this is intended to
-- be the general module for managing other formats as well.

require 'pl'
local utils = require 'pl.utils'
local quit = utils.quit
local markup = {}

function markup.create (ldoc, format)
   local ok,markup = pcall(require,format)
   if not ok then quit("cannot load formatter: "..format) end
   return function (txt)
      if txt == nil then return '' end
      -- inline <references> use same lookup as @see
      txt = txt:gsub('<([%w_%.]-)>',function(name)
         local ref = ldoc.module:process_see_reference(name,ldoc.modules)
         if not ref then print("could not find '"..name.."'"); return '' end
         local label = ref.label:gsub('_','\\_')
         local res = ('[%s](%s)'):format(label,ldoc.href(ref))
         return res
      end)
      -- workaround Markdown's need for blank lines around indented blocks
      -- (does mean you have to keep indentation discipline!)
      if txt:find '\n' and not ldoc.classic_markdown then -- multiline text
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
         txt =  table.concat(res,'\n')
      end
      txt = markup(txt)
      -- We will add our own paragraph tags, if needed.
      return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
   end
end


return markup
