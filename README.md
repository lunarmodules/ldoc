# LDoc - A Lua Documentation Tool

[![Luacheck](https://github.com/lunarmodules/LDoc/workflows/Luacheck/badge.svg)](https://github.com/lunarmodules/LDoc/actions)

Copyright (C) 2011-2012 Steve Donovan.

## Rationale

This project grew out of the documentation needs of
[Penlight](https://github.com/lunarmodules/Penlight) (and not always getting satisfaction
with LuaDoc) and depends on Penlight itself. (This allowed me to _not_ write a lot of code.)

The [API documentation](https://lunarmodules.github.io/Penlight/) of Penlight
is an example of a project using plain LuaDoc markup processed using LDoc.

LDoc is intended to be compatible with [LuaDoc](https://keplerproject.github.io/luadoc/) and
thus follows the pattern set by the various *Doc tools:

    --- Summary ends with a period.
    -- Some description, can be over several lines.
    -- @param p1 first parameter
    -- @param p2 second parameter
    -- @return a string value
    -- @see second_fun
    function mod1.first_fun(p1,p2)
    end

Tags such as `see` and `usage` are supported, and generally the names of functions and
modules can be inferred from the code.

LDoc is designed to give better diagnostics: if a `@see` reference cannot be found, then the
line number of the reference is given.  LDoc knows about modules which do not use `module()`
- this is important since this function has become deprecated in Lua 5.2. And you can avoid
having to embed HTML in commments by using Markdown.

LDoc will also work with Lua C extension code, and provides some convenient shortcuts.

An example showing the support for named sections and 'classes' is the [Winapi
documentation](https://stevedonovan.github.io/winapi/api.html); this is generated from
[winapi.l.c](https://github.com/stevedonovan/winapi/blob/master/winapi.l.c).

## Installation

This is straightforward; the only external dependency is
[Penlight](https://github.com/lunarmodules/Penlight), which in turn needs
[LuaFileSystem](https://lunarmodules.github.io/luafilesystem/). These are already present
in [Lua for Windows](https://github.com/rjpcomputing/luaforwindows), and Penlight is also available through [LuaRocks](https://luarocks.org/) as `luarocks install
penlight`.

Unpack the sources somewhere and make an alias to `ldoc.lua` on your path. That is, either
an executable script called 'ldoc' like so:

    lua /path/to/ldoc/ldoc.lua $*

Or a batch file called 'ldoc.bat':

    @echo off
    lua \path\to\ldoc\ldoc.lua %*

