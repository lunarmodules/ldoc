# LDoc Lua Documentation Tool

LDoc is intended to be compatible with [LuaDoc](http://luadoc.luaforge.net/manual.htm) and thus follows the pattern set by the various *Doc tools:

    --- first function. Some description
    -- @param p1 first parameter
    -- @param p2 second parameter
    function mod1.first_fun(p1,p2)
    end

Various tags such as `see` and `usage` are supported, and generally the names of functions and modules can be inferred from the code.  The project grew out of the documentation needs of Penlight (and not always getting satisfaction with LuaDoc) and depends on Penlight itself. This allowed me to _not_ write a lot of code.

LDoc tries to be faithful to LuaDoc, but provides some extensions. Here an alias for 'param' has been defined, and '@function zero_fun' is short for '@class function \ @name zero_fun'.

    --- zero function. Two new ldoc features here; item types
    -- can be used directly as tags, and aliases for tags
    -- can be defined in config.lp.
    -- @function zero_fun
    -- @p k1 first
    -- @p k2 second

If a file `config.lp` is found in the source, then it will be loaded as Lua data. For example:

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

LDoc tries to make it more convenient to organize documentation comments. Instead of:

    --- first table
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


LDoc can process C/C++ files:

    /***
    Create a table with given array and hash slots.
    @function createtable
    @param narr initial array slots, default 0
    @param nrec initial hash slots, default 0
    */
    static int l_createtable (lua_State *L) {
    ....

Both `/**` and `///` are recognized as starting a comment block.


The command-line options are:

    ldoc, a Lua documentation generator, vs 0.1 Beta
      -d,--dir (default docs) output directory
      -o  (default 'index') output name
      -v,--verbose          verbose
      -q,--quiet            suppress output
      -m,--module           module docs as text
      -s,--style (default !) directory for templates and style
      -p,--project (default ldoc) project name
      -t,--title (default Reference) page title
      -f,--format (default plain) formatting - can be markdown
      -b,--package  (default .) top-level package basename (needed for module(...))
      <file> (string) source file or directory containing source

For example, to process all files in the current directory:

    $ ldoc .
    output written to docs/

Thereafter the `docs` directory will contain `index.html` which points to individual modules in the `modules` subdirectory.  The `--dir` flag can specify where the output is generated, and ensures that the directory exists.

If your modules use `module(...)` then the module name has to be deduced. If `ldoc` is run from the root of the package, then this deduction does not need any help - e.g. if your package was `foo` then `ldoc foo` will work as expected. If we were actually in the `foo` directory then `ldoc -b .. .` will correctly deduce the module names.

For new-style modules, that don't use `module()`, it is recommended that the module comment has an explicit `@module PACKAGE.NAME`. If it does not, then `ldoc` will still attempt to deduce the module name, but may need help with `--package` as above.

It is common to use an alias for the package name with new-style modules. Here an alias is explicitly specified, so that `ldoc` knows that functions qualified with `M` are part of the module:

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



