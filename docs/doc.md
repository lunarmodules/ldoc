# LDoc - A Lua Documentation Tool

## LDoc as an improved LuaDoc

Generally, LuaDoc style documentation will be accepted.

Only 'doc comments' are parsed; these can be started with at least 3 hyphens, or by a empty comment line with at least 3 hypens:

    -----------------
    -- This will also do.

LDoc only does 'module' documentation, so the idea of 'files' is redundant. (If you want to document a script, there is a project-level type 'script' for that.)  By default it will process any file ending in `.lua` or `.luadoc`.

A stricter requirement is that any such file _must_ start with a 'doc comment'.

You may use block comments, like so:

    --[[--
    A simple function.
    @param a first parm
    @param b second parm
    ]]

    function simple(a,b)

This is useful for the initial module comment, which has the job of explaining the overall use of a module.

## LDoc is Extensible

LDoc tries to be faithful to LuaDoc, but provides some extensions.

'@function zero_fun' is short for the common sequence '@class function \ @name zero_fun'. In general, any type ('function','table',etc) can be used as a tag:

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
    @return the new table
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

It is common to use an alias for the package name with new-style modules. Here an alias is explicitly specified, so that `ldoc` knows that functions qualified with `A` are part of the module `simple_alias`:

    ------------
    -- A new-style module.
    -- @alias A

    local simple_alias = {}
    local A = simple_alias

    --- return the answer. And complete the description
    function A.answer()
      return 42
    end

    return simple_alias

(Here the actual module name is deduced from the file name, just like with `module(...)`)

It's semi-standard to use 'M' or '_M' for the module alias; LDoc will recognize these automatically.

By default, comments are treated verbatim and traditionally contain HTML. This is irritating for the human reader of the comments and tedious for the writer, so there is an option to use [Markdown](http://daringfireball.net/projects/markdown); `--format markdown`. This requires [markdown.lua](http://www.frykholm.se/files/markdown.lua) by Niklas Frykholm to be installed (this can be most easily done with `luarocks install markdown`.)  `format = 'markdown'` can be used in your `config.ld`.

A special case is if you simply say 'ldoc .'. Then there _must_ be a `config.ld` file available in the directory, and it can specify the file:

    file = "mymod.lua"
    title = "mymod documentation"
    description = "mymod does some simple but useful things"

`file` can of course point to a directory, just as with the `--file` option. This mode makes it particularly easy for the user to build the documentation, by allowing you to specify everything explicitly in the configuration.

## @see References

The example at `tests/complex` shows how @see references are interpreted:

    complex.util.parse
    complex.convert.basic
    complex.util
    complex.display
    complex

You may of course use the full name of a module or function, but can omit the top-level namespace - e.g. can refer to the module `util` and the function `display.display_that` directly. Within a module, you can directly use a function name, e.g. in `display` you can say `display_this`.

What applies to functions also applies to any module-level item like tables. New module-level items can be defined and they will work according to these rules.

If a reference is not found within the project, LDoc checks to see if it is a reference to a Lua standard function or table, and links to the online Lua manual.

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

Arguably a module writer should not write such very long modules, but it is not the job of the documentation tool to limit the programmer!

A specialized kind of section is `type`: it is used for documenting classes. The functions (or fields) within a type section are considered to be the methods of that class.

    --- A File class.
    -- @type File

    ....
    --- get the modification time.
    -- @return standard time since epoch
    function File:mtime()
    ...

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

There is a more customizable way to process the data, using the `--filter` parameter. This is understood to be a fully qualified function (module + name). For example, try

    $ ldoc --filter pl.pretty.dump mylib.c

to see a raw dump of the data.

LDoc takes this idea of data dumping one step further. If used with the `-m` flag it will look up an installed Lua module and parse it. If it has been marked up in LuaDoc-style then you will get a handy summary of the contents:

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

LDoc knows about the basic Lua libraries, so that it can be used as a handy console reference:

    $> ldoc -m assert

    function        assert(v, message)
    Issues an error when the value of its argument `v` is false (i.e.,
     nil or false); otherwise, returns all its arguments.
    `message` is an error
     message; when absent, it defaults to "assertion failed!"
    v
    message

Thanks to mitchell's [TextAdept](http://code.google.com/p/textadept/) project, LDoc has a set of `.luadoc` files for all the standard tables, plus [LuaFileSystem](http://keplerproject.github.com/luafilesystem/) and [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html).

    $> ldoc -m lfs.lock

    function        lock(filehandle, mode, start, length)
    Locks a file or a part of it.
    This function works on open files; the file
     handle should be specified as the first argument. The string mode could be
     either r (for a read/shared lock) or w (for a write/exclusive lock). The
     optional arguments start and length can be used to specify a starting point
     and its length; both should be numbers.
     Returns true if the operation was successful; in case of error, it returns
     nil plus an error string.
    filehandle
    mode
    start
    length

## Generating HTML

LDoc, like LuaDoc, generates output HTML using a template, in this case `ldoc.ltp`. This is expanded by the powerful but simple preprocessor devised originally by [Rici Lake](http://lua-users.org/wiki/SlightlyLessSimpleLuaPreprocessor) which is now part of Penlight. There are two rules - any line starting with '#' is Lua code, which can also be embedded with '$(...)'.

    <h2>Contents</h2>
    <ul>
    # for kind,items in module.kinds() do
    <li><a href="#$(no_spaces(kind))">$(kind)</a></li>
    # end
    </ul>

This is then styled with `ldoc.css`. Currently the template and stylesheet is very much based on LuaDoc, so the results are mostly equivalent; the main change that the template has been more generalized. The default location (indicated by '!') is the directory of `ldoc.lua`.

You may customize how you generate your documentation by specifying an alternative style sheet and/or template, which can be deployed with your project. The parameters are `--style` and `--template`, which give the directories where `ldoc.css` and `ldoc.ltp` are to be found. If `config.ld` contains these variables, they are interpreted slightly differently; if they are true, then it means 'use the same directory as config.ld'; otherwise they must be a valid directory relative to the ldoc invocation. An example of fully customized documentation is `tests/example/style': this is what you could call 'minimal Markdown style' where there is no attempt to tag things (except emphasizing parameter names). The narrative ought to be sufficient, if it is written appropriately.

Of course, there's no reason why LDoc must always generate HTML. `--ext' defines what output extension to use; this can also be set in the configuration file. So it's possible to write a template that converts LDoc output to LaTex, for instance.
