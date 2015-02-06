## Version 1.4.3

### Features

  * @include tag for including Markdown documentation file directly into module docstring
  * `prettify_files` makes per-item links to prettified source.
  * link targets rendered in bright yellow to make referenced functions more obvious
  * add update time to footer of page
  * better C support: `global_lookup=true` - invoked when `parse_extra={C=true}`
  * `kind_names` can override names used in sidebar
  
### Fixes

  * `all=true` in `config.ld` did not work.
  * `dont_escape_underscore` logic fixed: do not use in prettified code blocks
  * check that `ldoc` config exists before checking field values
  * annotation rendering fixed
  * summary not dropped when using `type` sections
  * directory as argument case was broken
  * parameter names which were List methods causing mayhem
  * files are processed in fixed order across platforms

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



