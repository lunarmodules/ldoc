------------
-- Functions with options.
-- @include opt.md

---- testing [opt]
-- @param one
-- @param[opt] two
-- @param[opt]three
-- @param[opt] four
function use_opt (one,two,three,four)
end

--- an explicit table.
-- Can now use tparam aliases in table defns
-- @string name
-- @int[opt=0] age
-- @table person2

