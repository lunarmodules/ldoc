-------
-- global functions and tables
local tools = require 'ldoc.tools'
local globals = {}


globals.functions = {
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
local functions = globals.functions

globals.tables = {
   io = '5.7',
   package = '5.3',
   math = '5.6',
   os = '5.8',
   string = '5.4',
   table = '5.5',
   coroutine = '5.2',
   debug = '5.9'
}
local tables = globals.tables

local manual, fun_ref

function globals.set_manual_url(url)
    manual = url .. '#'
    fun_ref = manual..'pdf-'
end
globals.set_manual_url 'http://www.lua.org/manual/5.1/manual.html'

local function function_ref (name)
   return {href = fun_ref..name, label = name}
end

local function module_ref (name)
   return {href = manual..tables[name], label = name}
end

function globals.lua_manual_ref (name)
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

return globals
