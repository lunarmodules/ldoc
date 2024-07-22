return [[
!local no_spaces = ldoc.no_spaces
!local function use_li(ls) return #ls > 1 and '- ' or '' end
!local display_name = ldoc.display_name
!local iter = ldoc.modules.iter
!local function M(txt,item) return ldoc.markup(txt,item,ldoc.plain) end
!local nowrap = ldoc.wrap and '' or 'nowrap'

!-- Menu --

# $(ldoc.project)

!if not ldoc.single and module then -- reference back to project index
[Index]($(ldoc.output))
!end

!--------- contents of module -------------
!if module and not ldoc.no_summary and #module.items > 0 then
## Contents

!	for kind,items in module.kinds() do
- [$(kind)](#$(no_spaces(kind)))
!	end
!end

!if ldoc.no_summary and module and not ldoc.one then -- bang out the functions on the side
!	for kind, items in module.kinds() do

## $(kind)

!		for item in items() do
- [$(display_name(item))](#$(item.name))
!		end
!	end
!end

!-------- contents of project ----------
!local this_mod = module and module.name
!for kind, mods, type in ldoc.kinds() do
!	if ldoc.allowed_in_contents(type,module) then

## $(kind)

!		for mod in mods() do local name = display_name(mod)
!			if mod.name == this_mod then
- **$(name)**
!			else
- [$(name)]($(ldoc.ref_to_module(mod):gsub('.html', '')))
!			end
!		end
!	end
!end

---

!if ldoc.body then -- verbatim HTML as contents; 'non-code' entries
$(ldoc.body)
!elseif module then -- module documentation
# $(ldoc.module_typename(module)) `$(module.name)`

$(M(module.summary,module))

$(M(module.description,module))

!	if module.tags.include then
$(M(ldoc.include_file(module.tags.include)))
!	end

!	if module.see then
!		local li = use_li(module.see)
### See also:

!		for see in iter(module.see) do
$(li)[$(see.label)]($(ldoc.href(see):gsub('.html', '')))
!		end -- for
!	end -- if see

!	if module.usage then
! local li = use_li(module.usage)
### Usage:

!		for usage in iter(module.usage) do
$(li)```lua
	$(ldoc.escape(usage))
	```
!		end -- for
!	end -- if usage

!	if module.info then
### Info:

!		for tag, value in module.info:iter() do
- **$(tag)**: $(M(value,module))
!		end
!	end -- if module.info

!	if not ldoc.no_summary then
!-- bang out the tables of item types for this module (e.g Functions, Tables, etc)
!		for kind,items in module.kinds() do
## [$(kind)](#$(no_spaces(kind)))

|||
|-|-|
!			for item in items() do
[$(display_name(item))](#$(item.name))|$(M(item.summary,item))
!			end -- for items
!		end -- for kinds
!	end -- if not no_summary

!--- currently works for both Functions and Tables. The params field either contains
!--- function parameters or table fields.
!	local show_return = not ldoc.no_return_or_parms
!	local show_parms = show_return
!	for kind, items in module.kinds() do
!		local kitem = module.kinds:get_item(kind)
!		local has_description = kitem and ldoc.descript(kitem) ~= ''
## $(kind)

$(M(module.kinds:get_section_description(kind),nil))

!		if kitem then
!			if has_description then
$(M(ldoc.descript(kitem),kitem))
!			end

!			if kitem.usage then
### Usage:

```lua
$(ldoc.prettify(kitem.usage[1]))
```
!			end
!		end

!		for item in items() do
!			if ldoc.prettify_files and ldoc.is_file_prettified[item.module.file.filename] then
### **$(display_name(item))**<span style='float:right;'>[line $(item.lineno)]($(ldoc.source_ref(item):gsub('.html', '')))</span>
!			else
### **$(display_name(item))**
!			end

$(M(ldoc.descript(item),item))

!			if ldoc.custom_tags then
!				for custom in iter(ldoc.custom_tags) do
!					local tag = item.tags[custom[1]]
!					if tag and not custom.hidden then
!						local li = use_li(tag)
#### $(custom.title or custom[1]):

!						for value in iter(tag) do
$(li)$(custom.format and custom.format(value) or M(value))
!						end -- for
!					end -- if tag
!				end -- iter tags
!			end

!			if show_parms and item.params and #item.params > 0 then
!				local subnames = module.kinds:type_of(item).subnames
!				if subnames then
#### $(subnames):
!				end

!				for parm in iter(item.params) do
!					local param,sublist = item:subparam(parm)
!					local indent = sublist and '  ' or ''
!					if sublist then
- $(sublist)$(M(item.params.map[sublist],item))
!					end
!					for p in iter(param) do
!						local name,tp,def = item:display_name_of(p), ldoc.typename(item:type_of_param(p)), item:default_of_param(p)
$(indent)- `$(name)`:
!						if tp ~= '' then
($(tp))
!						end
!						if def == true then
(_optional_)
!						elseif def then
(_default_: $(def))
!						end
!						if item:readonly(p) then
(_readonly_)
!						end
$(M(item.params.map[p],item))
!					end
!				end -- for
!			end -- if params

!			if show_return and item.retgroups then
!				local groups = item.retgroups
#### Returns:

!				for i,group in ldoc.ipairs(groups) do
!					local oli,uli = #group > 1 and '1. ','  - ' or '','- '
!					for r in group:iter() do
!						local type, ctypes = item:return_type(r)
!						local rt = ldoc.typename(type)
$(oli)$(rt ~= '' and '('..rt..')' or '') $(M(r.text,item))
!						if ctypes then
!							for c in ctypes:iter() do
$(uli)`$(c.name)` ($(ldoc.typename(c.type))) $(M(c.comment,item))
!							end
!						end -- if ctypes
!					end -- for r

!					if i < #groups then
##### Or
!					end

!				end -- for group
!			end -- if returns

!			if show_return and item.raise then
#### Raises:

$(M(item.raise,item))
!			end

!			if item.see then
!				local li = use_li(item.see)
#### See also:

!				for see in iter(item.see) do
$(li)[$(see.label)]($(ldoc.href(see):gsub('.html', '')))
!				end -- for
!			end -- if see

!			if item.usage then
!				local li = use_li(item.usage)
#### Usage:

!				for usage in iter(item.usage) do
$(li)```lua
	$(ldoc.prettify(usage))
	```
!				end -- for
!			end -- if usage
!		end -- for items
!	end -- for kinds
!else -- if module; project-level contents
!	if ldoc.description then
## $(M(ldoc.description,nil))
!	end

!	if ldoc.full_description then
$(M(ldoc.full_description,nil))
!	end

!	for kind, mods in ldoc.kinds() do
## $(kind)
! kind = kind:lower()
|||
|-|-|
!		for m in mods() do
[$(m.name)]($(no_spaces(kind))/$(m.name))|$(M(ldoc.strip_header(m.summary),m))
!		end -- for modules

!	end -- for kinds
!end -- if module

---

<i>generated by [LDoc $(ldoc.version)](http://github.com/stevedonovan/LDoc)</i>
<i style='float:right;'>Last updated $(ldoc.updatetime)</i>
]]
