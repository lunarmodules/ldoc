## Version 1.4.2

### Features

  * Can define fields/properties of objects; `readonly` modifier supported (#93)
  * Can switch off auto-linking to Lua manual with `no_lua_ref`
  * Module sorting is off by default, use `sort_modules=true`
  * References to 'classes' now work properly
  * Option to use first Markdown title instead of file names with `use_markdown_titles`
  * Automatic `Metamethods` and `Methods` sections generated for `classmod` classes
  * `unqualified=true` to strip package names on sidebar (#110)
  * Custom tags (which may be hidden)
  * Custom Display Name handlers

### Fixes

  * stricter about doc comments, now excludes common '----- XXXXX ----' pattern
  * no longer expects space after `##` in Markdown (#96)
  * Section lookup was broken
  * With `export` tag, decide whether method is static or not
  * `classmod` classes now respect custom sections (#113)
  * Minor issues with prettification
  * Command-line flags set explicitly take precendence over configuration file values.
  * Boilerplate Lua block comment ignored properly (#137)
  * Inline links with underscores sorted (#22)
  * Info section ordering is now consistent (#150)

## Version 1.4.0

### Features

  * `sort=true` to sort items within sections alphabetically
  * `@set` tag in module comments; e.g, can say `@set sort=true`
  * `@classmod` tag for defining modules that export one class
  * can generate Markdown output
  * Can prettify C as well as Lua code with built-in prettifier
  * lfs and lpeg references understood
  * 'pale' template available
  * multiple return groups
  * experimental `@error` tag
  * Moonscript and plain C support


### Fixes

  * works with non-compatibily Lua 5.2, including `markdown.lua`
  * module names can not be types
  * all `builtin` Lua files are requirable without `module`
  * backticks expand in copyright and other 'info' tabs
  * `-m` tries harder to resolve methods
  * auto-scroll in navigation area to avoid breaking identifiers
  * better error message for non-luadoc-compatible behaviour
  * custom see references fixed



