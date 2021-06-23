# LDoc - A Lua Documentation Tool

[![Luacheck](https://github.com/lunarmodules/LDoc/workflows/Luacheck/badge.svg)](https://github.com/lunarmodules/LDoc/actions)

Copyright (C) 2011-2012 Steve Donovan.

## Rationale

This project grew out of the documentation needs of
[Penlight](https://github.com/lunarmodules/Penlight) (and not always getting satisfaction
with LuaDoc) and depends on Penlight itself. (This allowed me to _not_ write a lot of code.)

The [API documentation](http://lunarmodules.github.com/Penlight/api/index.html) of Penlight
is an example of a project using plain LuaDoc markup processed using LDoc.

LDoc is intended to be compatible with [LuaDoc](http://keplerproject.github.io/luadoc/) and
thus follows the pattern set by the various \*Doc tools:

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
documentation](http://stevedonovan.github.io/winapi/api.html); this is generated from
[winapi.l.c](https://github.com/stevedonovan/winapi/blob/master/winapi.l.c).

## Installation

This is straightforward; the only external dependency is
[Penlight](https://github.com/lunarmodules/Penlight), which in turn needs
[LuaFileSystem](http://keplerproject.github.com/luafilesystem/). These are already present
in [Lua for Windows](https://github.com/rjpcomputing/luaforwindows), and Penlight is also available through [LuaRocks](https://luarocks.org/) as `luarocks install
penlight`.

Unpack the sources somewhere and make an alias to `ldoc.lua` on your path. That is, either
an executable script called 'ldoc' like so:

    lua /path/to/ldoc/ldoc.lua $*

Or a batch file called 'ldoc.bat':

    @echo off
    lua \path\to\ldoc\ldoc.lua %*


## Generating LDoc on github

To generate docs for your own lua projects see [doc.yml](.github/workflows/doc.yml).

Instead of `luarocks install --only-deps`, use `luarocks install
https://raw.githubusercontent.com/lunarmodules/LDoc/master/ldoc-scm-3.rockspec`
and create your own `doc-site` makefile target that runs `ldoc .` in the
directory containing your `config.ld`.

Ensure `publish_dir` in your doc.yml is set to the same location as your
`config.ld`'s `dir` parameter.

After you've pushed that change to master, you'll see the build cycle on your
commit (an orange dot or green checkmark). When that completes, a repo owner
needs to enable gh-pages on the repository: Settings > Pages and set "Source" to
gh-pages and root.

