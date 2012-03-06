----------------------
-- a module containing some classes.
-- @module classes

local _M = {}

---- a useful class.
-- @type Bonzo

_M.Bonzo = class()

--- a method.
-- function one
function Bonzo:one()

end

--- a metamethod
-- function __tostring
function Bonzo:__tostring()

end

return M

