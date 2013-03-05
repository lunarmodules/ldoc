--[[--------
A simple module with examples.

@module usage
]]

local usage = {}

----------
-- A simple vector class
-- @type Vector

local Vector = {}
usage.Vector = {}

----------
-- Create a vector from an array `t`.
function Vector.new (t)
end

----------
-- Create a vector from a string.
-- @usage
--  v = Vector.parse '[1,2,3]'
--  assert (v == Vector.new {1,2,3})
function Vector.parse (s)
end

----------
-- Add another vector, array or scalar `v` to this vector.
-- Returns new `Vector`
-- @usage assert(Vector.new{1,2,3}:add(1) == Vector{2,3,4})
function Vector:add (v)
end

return usage


