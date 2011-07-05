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
      txt = txt:gsub('<<([%w_%.]-)>>',function(ref)
         local ref = ldoc.module:process_see_reference(ref,ldoc.modules)
         local label = ref.label:gsub('_','\\_')
         local res = ('[%s](%s)'):format(label,ldoc.href(ref))
         return res
      end)
      if txt:find '\n' then -- multiline text
         local res = {}
         local last_line, last_indent = '', 0
         for line in stringx.lines(txt) do
            local indent = #line:match '^%s*'
            local litem = line:match '^%s%s*[%-%*]'
            if (litem and indent > last_indent) or (not litem and indent < last_indent) then
               table.insert(res,'')
            end
            table.insert(res,line)
            last_line, last_indent = line, indent
         end
         txt = table.concat(res,'\n')
      end
      txt = markup(txt)
      -- We will add our own paragraph tags, if needed.
      return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
   end
end


return markup
