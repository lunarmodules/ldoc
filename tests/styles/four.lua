------------
-- Yet another module.
-- @module four
-- Description can continue after simple tags, if you
-- like
-- @author bob, james
-- @license MIT
-- @copyright InfoReich 2013

--- a function with typed args.
-- Note the the standard tparam aliases, and how the 'opt' and 'optchain'
-- modifiers may also be used. If the Lua function has varargs, then
-- you may document an indefinite number of extra arguments!
-- @string name person's name
-- @int age
-- @string[opt] calender optional calendar
-- @int[optchain] offset optional offset
-- @treturn string
function one (name,age,...)
end


--- third useless function.
-- Can always put comments inline, may
-- be multiple.
-- note that first comment is refers to return
function three ( -- person:
    name, -- string: person's name
    age  -- int:
        -- not less than zero!
)

--- an implicit table.
-- Again, we can use the comments
person = {
    name = '', -- string: name of person
    age = 0, -- int:
}

--- an explicit table.
-- Can now use tparam aliases in table defns
-- @string name
-- @int age
-- @table person2

