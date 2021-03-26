--------------------------------------------------------------------------------
--! @file
--! @brief Various extensions to standard Lua libraries.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--
-- Formatting:
--  utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local error = error
local getmetatable = getmetatable
local string = require("string")
local table = require("table")
local type = type


-- strings --

--! Makes strings indexible like an immutable array of characters.
--!
--! @param s   target string.
--! @param idx index or key to look up.
--! @return    substring containing char at `idx`,
--!            requested metatable entry,
--!            or `nil` if `idx` isn't in-range/found.
--! @see       string.sub
getmetatable("").__index = function(s, idx)
	if type(idx) == "number" then return string.sub(s, idx, idx) end
	return string[idx]
end

-- tables --

--! Slices an array-style table; similar to a substring operation.
--!
--! @param t      target table.
--! @param iStart start index to begin slicing from.
--! @param iEnd   end index to finish slicing to; negative values are relative
--!               to the end of the table.
--! @return       a table, with values copied from the requested range of `t`.
table.slice = function(t, iStart, iEnd)
	-- allow negative end indices from end of list
	iEnd = iEnd or -1
	if iEnd < 0 then iEnd = (#t + 1) - iEnd end
	-- validate inputs
	if iStart < 1      or iStart > #t then error("bad argument #2 to 'slice' (position out of bounds)") end
	if iEnd   < iStart or iEnd   > #t then error("bad argument #3 to 'slice' (position out of bounds)") end

	local newT = {}
	for i = iStart, iEnd do table.insert(newT, t[i]) end
	return newT
end

--! `insert` alias intended to be used without an insertion point.
--!
--! @param t   target array-style table.
--! @param val value to insert at end of table.
table.push = table.insert
