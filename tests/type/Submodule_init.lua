-----------
-- Simple module distributed across two files.
-- This contains two types `Type1InSubmodule` and `Type2InSubmodule`.
-- While `Type1InSubmodule` is listed as a class in the generated docs,
-- `Type2InSubmodule` is not. Instead only its functions are listed.
-- @module DistributedModule

--- Type1InSubmodule description.
-- @type Type1InSubmodule
Type1InSubmodule = {}

--- Type1InSubmodule:A description.
function Type1InSubmodule:A()

end
