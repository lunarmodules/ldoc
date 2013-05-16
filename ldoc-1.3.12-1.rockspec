package = "ldoc"
version = "1.3.12-1"

source = {
  dir="ldoc",
  url = "http://stevedonovan.github.com/files/ldoc-1.3.12.zip"
}

description = {
  summary = "A Lua Documentation Tool",
  detailed = [[
   LDoc is a LuaDoc-compatible documentation generator which can also
   process C extension source. Markdown may be optionally used to
   render comments, as well as integrated readme documentation and
   pretty-printed example files
  ]],
  homepage='http://stevedonovan.github.com/ldoc',
  maintainer='steve.j.donovan@gmail.com',
  license = "MIT/X11",
}


dependencies = {
  "penlight","markdown"
}

build = {
  type = "builtin",
  modules = {
    ["ldoc.tools"] = "ldoc/tools.lua",
    ["ldoc.lang"] = "ldoc/lang.lua",
    ["ldoc.parse"] = "ldoc/parse.lua",
    ["ldoc.html"] = "ldoc/html.lua",
    ["ldoc.lexer"] = "ldoc/lexer.lua",
    ["ldoc.markup"] = "ldoc/markup.lua",
    ["ldoc.prettify"] = "ldoc/prettify.lua",
    ["ldoc.doc"] = "ldoc/doc.lua",
    ["ldoc.html.ldoc_css"] = "ldoc/html/ldoc_css.lua",
    ["ldoc.html.ldoc_ltp"] = "ldoc/html/ldoc_ltp.lua",
    ["ldoc.html.ldoc_one_css"] = "ldoc/html/ldoc_one_css.lua",
    ["ldoc.builtin.globals"] = "ldoc/builtin/globals.lua",
    ["ldoc.builtin.coroutine"] = "ldoc/builtin/coroutine.lua",
    ["ldoc.builtin.global"] = "ldoc/builtin/global.lua",
    ["ldoc.builtin.debug"] = "ldoc/builtin/debug.lua",
    ["ldoc.builtin.io"] = "ldoc/builtin/io.lua",
    ["ldoc.builtin.lfs"] = "ldoc/builtin/lfs.lua",
    ["ldoc.builtin.lpeg"] = "ldoc/builtin/lpeg.lua",
    ["ldoc.builtin.math"] = "ldoc/builtin/math.lua",
    ["ldoc.builtin.os"] = "ldoc/builtin/os.lua",
    ["ldoc.builtin.package"] = "ldoc/builtin/package.lua",
    ["ldoc.builtin.string"] = "ldoc/builtin/string.lua",
    ["ldoc.builtin.table"] = "ldoc/builtin/table.lua",
  },
  install = {
    bin = {
      ldoc = "ldoc.lua"
    }
  }
}


