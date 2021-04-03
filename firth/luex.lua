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


local string = require("string")
local table = require("table")

local error = error
local getmetatable = getmetatable
local select = select
local type = type


---------------- strings ----------------

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

---------------- tables ----------------

--! Slices an array-style table; similar to a substring operation.
--!
--! @param t      target table.
--! @param iStart start index to begin slicing from.
--! @param iEnd   end index to finish slicing to; negative values are relative
--!               to the end of the table.
--! @return       a table, with values copied from the requested range of `t`.
function table.slice(t, iStart, iEnd)
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

--! Assigns all fields of sebsequent args to `t`.
--!
--! Very similar to JavaScript's `Object.assign(obj, ...)`. Modifies the first
--! argument `t`, but also returns it, to support the very common usecase:
--! ```Lua
--! local foo = table.assign({ name = "foo" }, bar, baz)
--! ```
--!
--! @note This is not a deep copy operation. For each `v` in `ti[k]`,
--!       it is simply assigned `t[k] = v`.
--!
--! @todo `table.iassign()` variant that uses `ipairs()`?
--!
--! @param[out] t   table to assing fields to.
--! @param      ... varag list of tables to assign to `t`.
--! @return         `t`, modified with any fields from the following args.
function table.assign(t, ...)
	for i = 1, select('#', ...) do
		local t2 = select(i, ...)
		for k, v in pairs(t2) do t[k] = v end
	end
	return t
end

function table.freeze(t)
	local mt = table.assign({}, t)
	-- TODO: some way to iterate values
	function mt.__newindex()
		error("Attemped to mutate a frozen table")
	end
	mt.__index = mt
	return setmetatable({}, mt)
end

function table.map(t, f)
	local out = {}
	for i, v in ipairs(t) do out[i] = f(t[i]) end
	return out
end

function table.kmap(t, f)
	local out = {}
	for k, v in pairs(t) do out[k] = f(t[k]) end
	return out
end
