------------
-- Yet another module.
-- @module four
-- Description can continue after simple tags, if you
-- like
-- @author bob, james
-- @license MIT
-- @copyright InfoReich 2013

--- a function with typed args.
-- Note the the standard tparam aliases
-- @string name person's name
-- @int age
-- @treturn string
function one (name,age)
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

