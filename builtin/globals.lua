-------
-- global functions and tables
local tools = require 'ldoc.tools'



local functions = {
   assert = true,
   collectgarbage = true,
   dofile = true,
   setfenv = true,
   getfenv = true,
   getmetatable = true,
   setmetatable = true,
   pairs = true,
   ipairs = true,
   load = true,
   loadfile = true,
   loadstring = true,
   next = true,
   pcall = true,
   print = true,
   rawequal = true,
   rawget = true,
   rawset = true,
   select = true,
   tonumber = true,
   tostring = true,
   type = true,
   unpack = true,
   xpcall = true,
   module = true,
   require = true,
}

local tables = {
   io = '5.7',
   package = '5.3',
   math = '5.6',
   os = '5.8',
   string = '5.4',
   table = '5.5',
   coroutine = '5.2',
   debug = '5.9'
}

local manual = 'http://www.lua.org/manual/5.1/manual.html#'
local fun_ref = manual..'pdf-'

local function function_ref (name)
   return {href = fun_ref..name}
end

local function module_ref (name)
   return {href = manual..tables[name]}
end


local function lua_manual_ref (name)
   local tbl,fname = tools.split_dotted_name(name)
   if not tbl then -- plain symbol
      if functions[name] then
         return function_ref(name)
      end
      if tables[name] then
         return module_ref(name)
      end
   else
      if tables[tbl] then
         return function_ref(name)
      end
   end
   return nil
end

return {
   functions = functions,
   tables = tables,
   lua_manual_ref = lua_manual_ref
}
