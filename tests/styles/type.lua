-----
-- module containing a class
-- @module type

----
-- Our class.
-- @type Bonzo

----
-- make a new Bonzo
-- @string s name of Bonzo
function Bonzo.new(s)
end

-----
-- get a string representation.
function Bonzo.__tostring()
end

----
-- A subtable with fields.
-- @table Details
-- @string[readonly] name
-- @int[readonly] age

---
-- This is a simple field/property of the class.
-- @string[opt="Bilbo",readonly] frodo direct access to text
