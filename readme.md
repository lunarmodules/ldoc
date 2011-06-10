# LDoc - A Lua Documentation Tool

Copyright (C) 2011 Steve Donovan.

## LDoc as an improved LuaDoc

LDoc is intended to be compatible with [LuaDoc](http://luadoc.luaforge.net/manual.htm) and thus follows the pattern set by the various *Doc tools:

    --- Summary ends with a period.
    -- Some description, can be over several lines.
    -- @param p1 first parameter
    -- @param p2 second parameter
    -- @return a string value
    -- @see second_fun
    function mod1.first_fun(p1,p2)
    end

Tags such as `see` and `usage` are supported, and generally the names of functions and modules can be inferred from the code.

This project grew out of the documentation needs of Penlight (and not always getting satisfaction with LuaDoc) and depends on Penlight itself. This allowed me to _not_ write a lot of code.

Any claim about 'improvement' needs substantiation. LDoc is designed to give better diagnostics: if a '@see` reference cannot be found, then the line number of the reference is given.  LDoc knows about modules which do not use `module()` - this is important since this function has become deprecated in Lua 5.2. And you can avoid having to embed HTML in commments by using Markdown.

## Installation

This should be fairly straightforward; the external dependency is [Penlight](), which in turn needs [LuaFileSystem](). These are already present in Lua for Windows, and Penlight is also available through LuaRocks as 'luarocks install penlight'.

Unpack the sources somewhere and make an alias to `ldoc.lua` on your path. That is, either an excutable script called 'ldoc' like so:

    lua /path/to/ldoc/ldoc.lua $*

Or a batch file called 'ldoc.bat':

    @echo off
    lua \path\to\ldoc\ldoc.lua %*


## LDoc is Extensible

LDoc tries to be faithful to LuaDoc, but provides some extensions. '@function zero_fun' is short for the common sequence '@class function \ @name zero_fun'. In general, any type ('function','table',etc) can be used as a tag:

    --- zero function. Two new ldoc features here; item types
    -- can be used directly as tags, and aliases for tags
    -- can be defined in config.ld.
    -- @function zero_fun
    -- @p k1 first
    -- @p k2 second

Here an alias for 'param' has been defined. If a file `config.ld` is found in the source, then it will be loaded as Lua data. For example, the configuration for the above module provides a title and defines an alias for 'param':

    title = "testmod docs"
    project = "testmod"
    alias("p","param")

Extra tag types can be defined:

    new_type("macro","Macros")

And then used as any other tag:

    -----
    -- A useful macro. This is an example of a custom 'kind'.
    -- @macro first_macro
    -- @see second_function

This will also create a new module section called 'Macros'.

## Inferring more from Code

The qualified name of a function will be inferred from any `function` keyword following the doc comment. LDoc goes further with code analysis, however.

Instead of:

    --- first table.
    -- @table one
    -- @field A alpha
    -- @field B beta
    M.one = {
        A = 1,
        B = 2;
    }

you can write:

    --- first table
    -- @table one
    M.one = {
        A = 1, -- alpha
        B = 2; -- beta
    }

Simularly, function parameter comments can be directly used:

    ------------
    -- third function. Can also provide parameter comments inline,
    -- provided they follow this pattern.
    function mod1.third_function(
        alpha, -- correction A
        beta, -- correction B
        gamma -- factor C
        )
        ...
    end

## Supporting Extension modules written in C

LDoc can process C/C++ files:

    /***
    Create a table with given array and hash slots.
    @function createtable
    @param narr initial array slots, default 0
    @param nrec initial hash slots, default 0
    */
    static int l_createtable (lua_State *L) {
    ....

Both `/**` and `///` are recognized as starting a comment block. Otherwise, the tags are processed in exactly the same way. It is necessary to specify that this is a function with a given name, since this cannot be reliably be inferred from code.

An unknown extension can be associated with a language using a call like `add_language_extension('lc','c')` in `config.ld`. (Currently the language can only be 'c' or 'lua'.)

See 'tests/examples/mylib.c' for the full example.

## Basic Usage

The command-line options are:

    ldoc, a documentation generator for Lua, vs 0.2 Beta
      -d,--dir (default docs) output directory
      -o,--output  (default 'index') output name
      -v,--verbose          verbose
      -q,--quiet            suppress output
      -m,--module           module docs as text
      -s,--style (default !) directory for style sheet (ldoc.css)
      -l,--template (default !) directory for template (ldoc.ltp)
      -p,--project (default ldoc) project name
      -t,--title (default Reference) page title
      -f,--format (default plain) formatting - can be markdown or plain
      -b,--package  (default .) top-level package basename (needed for module(...))
      -x,--ext (default html) output file extension
      --dump                debug output dump
      <file> (string) source file or directory containing source

For example, to process all files in the 'lua' directory:

    $ ldoc lua
    output written to docs/

Thereafter the `docs` directory will contain `index.html` which points to individual modules in the `modules` subdirectory.  The `--dir` flag can specify where the output is generated, and will ensure that the directory exists. The output structure is like LuaDoc: there is an `index.html` and the individual modules are in the `modules` subdirectory.

If your modules use `module(...)` then the module name has to be deduced. If `ldoc` is run from the root of the package, then this deduction does not need any help - e.g. if your package was `foo` then `ldoc foo` will work as expected. If we were actually in the `foo` directory then `ldoc -b .. .` will correctly deduce the module names.

For new-style modules, that don't use `module()`, it is recommended that the module comment has an explicit `@module PACKAGE.NAME`. If it does not, then `ldoc` will still attempt to deduce the module name, but may need help with `--package` as above.

It is common to use an alias for the package name with new-style modules. Here an alias is explicitly specified, so that `ldoc` knows that functions qualified with `M` are part of the module `simple_alias`:

    ------------
    -- A new-style module.
    -- @alias M

    local simple_alias = {}
    local M = simple_alias

    --- return the answer. And complete the description
    function M.answer()
      return 42
    end

    return simple_alias

(Here the actual module name is deduced from the file name, just like with `module(...)`)

A special case is if you simply say 'ldoc .'. Then there _must_ be a `config.ld` file available in the directory, and it can specify the file:

    file = "mymod.lua"
    title = "mymod documentation"
    description = "mymod does some simple but useful things"

`file` can of course point to a directory, just as with the `--file` option. This mode makes it particularly easy for the user to build the documentation, by allowing you to specify everything explicitly in the configuration.

## Processing Single Modules

`--output` can be used to give the output file a different name. This is useful for the special case when a single module file is specified. Here an index would be redundant, so the single HTML file generated contains the module documentation.

    $ ldoc mylib.lua --> results in docs/index.html
    $ ldoc --output mylib mylib.lua --> results in docs/mylib.html
    $ ldoc --output mylib --dir html mylib.lua --> results in html/mylib.html


## Sections

The default sections used by LDoc are 'Functions', 'Tables' and 'Fields', corresponding to the built-in types 'function', 'table' and 'field'. If `config.ld` contains something like `new_type("macro","Macros")` then this adds a new section 'Macros' which contains items of 'macro' type - 'macro' is registered as a new valid tag name.  The default template then presents items under their corresponding section titles, in order of definition.

New with this release is the idea of _explicit_ sections. The need occurs when a module has a lot of functions that need to be put into logical sections.

    --- File functions.
    -- Useful utilities for opening foobar format files.
    -- @section file

    --- open a file
    ...

    --- read a file
    ...

    --- Encoding operations.
    -- Encoding foobar output in different ways.
    -- @section encoding

    ...

A section doc-comment has the same structure as a normal doc-comment; the summary is used as the new section title, and the description will be output at the start of the function details for that section.

In any case, sections appear under 'Contents' on the left-hand side. See the [winapi](http://stevedonovan.github.com/winapi/api.html) documentation for an example of how this looks.

Arguably a module writer should not write such very long modules, but it is not the job of the documentation tool to limit a programmer.

## Dumping and getting Help about a Module

There is an option to simply dump the results of parsing modules. Consider the C example `tests/example/mylib.c':

    $ ldoc --dump mylib.c
    ----
    module: mylib   A sample C extension.
    Demonstrates using ldoc's C/C++ support. Can either use /// or /*** */ etc.

    function        createtable(narr, nrec)
    Create a table with given array and hash slots.
    narr     initial array slots, default 0
    nrec     initial hash slots, default 0

    function        solve(a, b, c)
    Solve a quadratic equation.
    a        coefficient of x^2
    b        coefficient of x
    c        constant
    return  {"first root","second root"}

This is useful to quickly check for problems; here we see that `createable` did not have a return tag.

LDoc takes this idea one step further. If used with the `-m` flag it will look up an installed Lua module and parse it. If it has been marked up in LuaDoc-style then you will get a handy summary of the contents:

    $ ldoc -m pl.pretty
    ----
    module: pl.pretty       Pretty-printing Lua tables.
    * read(s) - read a string representation of a Lua table.
    * write(tbl, space, not_clever) - Create a string representation of a Lua table.

    * dump(t, ...) - Dump a Lua table out to a file or stdout.

You can specify a fully qualified function to get more information:

    $ ldoc -m pl.pretty.write

    function        write(tbl, space, not_clever)
    create a string representation of a Lua table.
    tbl      {table} Table to serialize to a string.
    space    {string} (optional) The indent to use.
                   Defaults to two spaces.
    not_clever       {bool} (optional) Use for plain output, e.g {['key']=1}.
                   Defaults to false.

## Generating HTML

LDoc, like LuaDoc, generates output HTML using a template, in this case `ldoc.ltp`. This is expanded by the powerful but simple preprocessor devised originally by [Rici Lake](http://lua-users.org/wiki/SlightlyLessSimpleLuaPreprocessor) which is now part of Penlight. There are two rules - any line starting with '#' is Lua code, which can also be embedded with '$(...)'.

    <h2>Contents</h2>
    <ul>
    # for kind,items in module.kinds() do
    <li><a href="#$(no_spaces(kind))">$(kind)</a></li>
    # end
    </ul>

This is then styled with `ldoc.css`. Currently the template and stylesheet is very much based on LuaDoc, so the results are equivalent; the main change that the template has been more generalized. The default location (indicated by '!') is the directory of `ldoc.lua`.

You may customize how you generate your documentation by specifying an alternative style sheet and/or template, which can be deployed with your project. The parameters are `--style` and `--template`, which give the directories where `ldoc.css` and `ldoc.ltp` are to be found. If `config.ld` contains these variables, they are interpreted slightly differently; if they are true, then it means 'use the same directory as config.ld'; otherwise they must be a valid directory relative to the ldoc invocation.

Of course, there's no reason why LDoc must always generate HTML. `--ext' defines what output extension to use; this can also be set in the configuration file. So it's possible to write a template that converts LDoc output to LaTex, for instance.
