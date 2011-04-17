------------
-- A module containing tables.
-- Shows how Lua table definitions can be conveniently parsed.
-- @alias M

local tables = {}
local M = tables

--- first table
-- @table one
M.one = {
    A = 1, -- alpha
    B = 2; -- beta
}

return M

