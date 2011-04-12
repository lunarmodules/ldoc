# LDoc Lua Documentation Tool

LDoc is intended to be compatible with [LuaDoc](http://luadoc.luaforge.net/manual.htm) and thus follows the pattern set by the various *Doc tools:

    --- first function. Some description
    -- @param p1 first parameter
    -- @param p2 second parameter
    function mod1.first_fun(p1,p2)
    end

Various tags such as `see` and `usage` are supported, and generally the names of functions and modules can be inferred from the code.  The project grew out of the documentation needs of Penlight (and not always getting satisfaction with LuaDoc) and depends on Penlight itself. This allowed me to _not_ write a lot of code.

LDoc tries to be faithful to LuaDoc, but provides some extensions

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
      -d,--dir (default .) output directory
      -o  (default 'index') output name
      -v,--verbose          verbose
      -q,--quiet            suppress output
      -m,--module           module docs as text
      -s,--style (default !) directory for templates and style
      -p,--project (default ldoc) project name
      -t,--title (default Reference) page title
      -f,--format (default plain) formatting - can be markdown
      -b,--package  (default '') top-level package basename (needed for module(...))
      <file> (string) source file or directory containing source

