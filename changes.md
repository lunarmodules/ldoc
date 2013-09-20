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



