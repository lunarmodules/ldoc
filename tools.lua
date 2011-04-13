---------
-- General utility functions for ldoc
-- @module tools

require 'pl'
local tools = {}
local M = tools
local append = table.insert
local lexer = require 'lexer'
local quit = utils.quit

-- this constructs an iterator over a list of objects which returns only
-- those objects where a field has a certain value. It's used to iterate
-- only over functions or tables, etc.
-- (something rather similar exists in LuaDoc)
function M.type_iterator (list,field,value)
    return function()
        local i = 1
        return function()
            local val = list[i]
            while val and val[field] ~= value do
                i = i + 1
                val = list[i]
            end
            i = i + 1
            if val then return val end
        end
    end
end

-- KindMap is used to iterate over a set of categories, called _kinds_,
-- and the associated iterator over all items in that category.
-- For instance, a module contains functions, tables, etc and we will
-- want to iterate over these categories in a specified order:
--
--  for kind, items in module.kinds() do
--    print('kind',kind)
--    for item in items() do print(item.name) end
--  end
--
-- The kind is typically used as a label or a Title, so for type 'function' the
-- kind is 'Functions' and so on.

local KindMap = class()
M.KindMap = KindMap

-- calling a KindMap returns an iterator. This returns the kind, the iterator
-- over the items of that type, and the corresponding type.
function KindMap:__call ()
    local i = 1
    local klass = self.klass
    return function()
        local kind = klass.kinds[i]
        if not kind then return nil end -- no more kinds
        while not self[kind] do
            i = i + 1
            kind = klass.kinds[i]
            if not kind then return nil end
        end
        i = i + 1
        return kind, self[kind], klass.types_by_kind[kind]
    end
end

-- called for each new item. It does not actually create separate lists,
-- (although that would not break the interface) but creates iterators
-- for that item type if not already created.
function KindMap:add (item,items)
    local kname = self.klass.types_by_tag[item.type]
    if not self[kname] then
        self[kname] = M.type_iterator (items,'type',item.type)
    end
end

-- KindMap has a 'class constructor' which is used to modify
-- any new base class.
function KindMap._class_init (klass)
    klass.kinds = {} -- list in correct order of kinds
    klass.types_by_tag = {} -- indexed by tag
    klass.types_by_kind = {} -- indexed by kind
end


function KindMap.add_kind (klass,tag,kind,subnames)
    klass.types_by_tag[tag] = kind
    klass.types_by_kind[kind] = {type=tag,subnames=subnames}
    append(klass.kinds,kind)
end


----- some useful utility functions ------

function M.module_basepath()
    local lpath = List.split(package.path,';')
    for p in lpath:iter() do
        local p = path.dirname(p)
        if path.isabs(p) then
            return p
        end
    end
end

-- split a qualified name into the module part and the name part,
-- e.g 'pl.utils.split' becomes 'pl.utils' and 'split'
function M.split_dotted_name (s)
    local s1,s2 = path.splitext(s)
    if s2=='' then return nil
    else  return s1,s2:sub(2)
    end
end

-- expand lists of possibly qualified identifiers
-- given something like {'one , two.2','three.drei.drie)'}
-- it will output {"one","two.2","three.drei.drie"}
function M.expand_comma_list (ls)
    local new_ls = List()
    for s in ls:iter() do
        s = s:gsub('[^%.:%w]*$','')
        if s:find ',' then
            new_ls:extend(List.split(s,'%s*,%s*'))
        else
            new_ls:append(s)
        end
    end
    return new_ls
end

function M.extract_identifier (value)
    return value:match('([%.:_%w]+)')
end

function M.strip (s)
    return s:gsub('^%s+',''):gsub('%s+$','')
end

function M.check_directory(d)
    if not path.isdir(d) then
        lfs.mkdir(d)
    end
end

function M.check_file (f,original)
    if not path.exists(f) then
        dir.copyfile(original,f)
    end
end

function M.writefile(name,text)
    local ok,err = utils.writefile(name,text)
    if err then quit(err) end
end

function M.name_of (lpath)
    lpath,ext = path.splitext(lpath)
    return lpath
end

function M.this_module_name (basename,fname)
    local ext
    if basename == '' then
        --quit("module(...) needs package basename")
        return M.name_of(fname)
    end
    basename = path.abspath(basename)
    if basename:sub(-1,-1) ~= path.sep then
        basename = basename..path.sep
    end
    local lpath,cnt = fname:gsub('^'..utils.escape(basename),'')
    if cnt ~= 1 then quit("module(...) name deduction failed: base "..basename.." "..fname) end
    lpath = lpath:gsub(path.sep,'.')
    return M.name_of(lpath)
end


--------- lexer tools -----

local tnext = lexer.skipws

local function type_of (tok) return tok[1] end
local function value_of (tok) return tok[2] end

-- This parses Lua formal argument lists. It will return a list of argument
-- names, which also has a comments field, which will contain any commments
-- following the arguments. ldoc will use these in addition to explicit
-- param tags.

function M.get_parameters (tok)
    local args = List()
    args.comments = {}
    local ltl = lexer.get_separated_list(tok)

    if #ltl[1] == 0 then return args end -- no arguments

    local function set_comment (idx,tok)
        args.comments[args[idx]] = value_of(tok)
    end

    for i = 1,#ltl do
        local tl = ltl[i]
        if type_of(tl[1]) == 'comment' then
            if i > 1 then set_comment(i-1,tl[1]) end
            if #tl > 1 then
                args:append(value_of(tl[2]))
            end
        else
            args:append(value_of(tl[1]))
        end
        if i == #ltl then
            local last_tok = tl[#tl]
            if #tl > 1 and type_of(last_tok) == 'comment' then
                set_comment(i,last_tok)
            end
        end
    end

    return args
end

-- parse a Lua identifier - contains names separated by . and :.
function M.get_fun_name (tok)
    local res = {}
    local _,name = tnext(tok)
    _,sep = tnext(tok)
    while sep == '.' or sep == ':' do
        append(res,name)
        append(res,sep)
        _,name = tnext(tok)
        _,sep = tnext(tok)
    end
    append(res,name)
    return table.concat(res)
end

-- space-skipping version of token iterator
function M.space_skip_getter(tok)
    return function ()
        local t,v = tok()
        while t and t == 'space' do
            t,v = tok()
        end
        return t,v
    end
end

-- an embarassing function. The PL Lua lexer does not do block comments
-- when used in line-grabbing mode, and in fact (0.9.4) does not even
-- do them properly in full-text mode, due to a ordering mistake.
-- So, we do what we can ;)
function M.grab_block_comment (v,tok,end1,end2)
    local res = {v}
    local t,last_v
    repeat
        last_v = v
        t,v = tok()
        append(res,v)
    until last_v == end1 and v == end2
    table.remove(res)
    table.remove(res)
    res = table.concat(res)
    return 'comment',res
end



return tools
