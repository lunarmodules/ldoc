--------------
-- Handling markup transformation.
-- Currently just does Markdown, but this is intended to
-- be the general module for managing other formats as well.

local utils = require 'pl.utils'
local quit = utils.quit
local markup = {}

function markup.create (format)
   local ok,markup = pcall(require,format)
   if not ok then quit("cannot load formatter: "..format) end
   return function (txt)
      if txt == nil then return '' end
      txt = markup(txt)
      return (txt:gsub('^%s*<p>(.+)</p>%s*$','%1'))
   end
end


return markup
