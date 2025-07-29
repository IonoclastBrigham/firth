--------------------------------------------------------------------------------
--! @file
--! @brief Fast Lua Interface - launguage bindings for :Firth.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021-2025 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--!
--! @see proto/bootstrap.lua
--
-- Formatting:
--  utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local assert = assert
local getmetatable, setmetatable = getmetatable, setmetatable
local pairs = pairs
local print = print
local select = select
local setfenv = setfenv or require 'compat.compat_env'.setfenv
local string = string
local table = table
local type = type

require "firth.luex"


local module = {}
setfenv(1, module)


function luaN(xt, n, ...)
	local f = dispatch[n]
	return f(xt, ...)
end

--! @cond

-- 0 parameters

function lua0_0(xt, ...)
	xt()
	return ...
end

function lua0_1(xt, ...)
	return xt(), ...
end

function lua0_2(xt, ...)
	local r1, r2 = xt()
	return r1, r2, ...
end

function lua0_3(xt, ...)
	local r1, r2, r3 = xt()
	return r1, r2, r3, ...
end

-- 1 parameter

function lua1_0(xt, p1, ...)
	xt(p1)
	return ...
end

function lua1_1(xt, p1, ...)
	return xt(p1), ...
end

function lua1_2(xt, p1, ...)
	local r1, r2 = xt(p1)
	return r1, r2, ...
end

function lua1_3(xt, p1, ...)
	local r1, r2 = xt(p1)
	return r1, r2, ...
end

-- 2 parameters

function lua2_0(xt, p2, p1, ...)
	xt(p1, p2)
	return ...
end

function lua2_1(xt, p2, p1, ...)
	return xt(p1, p2), ...
end

function lua2_2(xt, p2, p1, ...)
	local r1, r2 = xt(p1, p2)
	return r1, r2, ...
end

function lua2_3(xt, p2, p1, ...)
	local r1, r2, r3 = xt(p1, p2)
	return r1, r2, r3, ...
end

function lua3_0(xt, p3, p2, p1, ...)
	xt(p1, p2, p3)
	return ...
end

-- 3 parameters

function lua3_1(xt, p3, p2, p1, ...)
	return xt(p1, p2, p3), ...
end

function lua3_2(xt, p3, p2, p1, ...)
	local r1, r2 = xt(p1, p2, p3)
	return r1, r2, ...
end

function lua3_3(xt, p3, p2, p1, ...)
	local r1, r2, r3 = xt(p1, p2, p3)
	return r1, r2, r3, ...
end

-- 4 parameters

function lua4_0(xt, p4, p3, p2, p1, ...)
	xt(p1, p2, p3, p4)
	return ...
end

function lua4_1(xt, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4), ...
end

function lua4_2(xt, p4, p3, p2, p1, ...)
	local r1, r2 = xt(p1, p2, p3, p4)
	return r1, r2, ...
end

function lua4_3(xt, p4, p3, p2, p1, ...)
	local r1, r2, r3 = xt(p1, p2, p3, p4)
	return r1, r2, r3, ...
end

-- 5 parameters

function lua5_0(xt, p5, p4, p3, p2, p1, ...)
	xt(p1, p2, p3, p4, p5)
	return ...
end

function lua5_1(xt, p5, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4, p5), ...
end

function lua5_2(xt, p5, p4, p3, p2, p1, ...)
	local r1, r2 = xt(p1, p2, p3, p4, p5)
	return r1, r2, ...
end

function lua5_3(xt, p5, p4, p3, p2, p1, ...)
	local r1, r2, r3 = xt(p1, p2, p3, p4, p5)
	return r1, r2, r3, ...
end

-- 6 parameters

function lua6_0(xt, p6, p5, p4, p3, p2, p1, ...)
	xt(p1, p2, p3, p4, p5, p6)
	return ...
end

function lua6_1(xt, p6, p5, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4, p5, p6), ...
end

function lua6_2(xt, p6, p5, p4, p3, p2, p1, ...)
	local r1, r2 = xt(p1, p2, p3, p4, p5, p6)
	return r1, r2, ...
end

function lua6_3(xt, p6, p5, p4, p3, p2, p1, ...)
	local r1, r2, r3 = xt(p1, p2, p3, p4, p5, p6)
	return r1, r2, r3, ...
end

local dispatch = {
	{ lua1_1, lua1_2, lua1_3 },
	{ lua2_1, lua2_2, lua2_3 },
	{ lua3_1, lua3_2, lua3_3 },
	{ lua4_1, lua4_2, lua4_3 },
	{ lua5_1, lua5_2, lua5_3 },
	{ lua6_1, lua6_2, lua6_3 }
}
dispatch[0] = { lua0_1, lua0_2, lua0_3 }
dispatch[0][0] = lua0_0
dispatch[1][0] = lua1_0
dispatch[2][0] = lua2_0
dispatch[3][0] = lua3_0
dispatch[4][0] = lua4_0
dispatch[5][0] = lua5_0
dispatch[6][0] = lua6_0

--! @endcond


--! Wraps a Lua function for use as a :Firth word.
--!
--! @param f    {function} the Lua function to wrap.
--! @param argc {number}   number of arguments to pull from :Firth stack.
--! @param retc {number}   number of returns from `f`; defaults to `1`.
--! @return                `retc` values returned from `f()`.
function wrapfunc(f, argc, retc)
	retc = retc or 1
	local luafunc = dispatch[argc][retc]
	return function(...)
		return luafunc(f, ...)
	end
end

function wrapmodule(module, defs)
	for luafunc, signature in pairs(defs) do
		if type(signature) == "table" then
			if #signature > 0 then -- is "array"
				assert(#signature >= 2, "Invalid signature for function '"..luafunc.."': "..table.concat(signature))
				local retc = signature[#signature]
				for i = 1, #signature - 1 do
					local targetfunc = (#signature > 2) and luafunc..signature[i] or luafunc
					module[targetfunc] = wrapfunc(module[luafunc], signature[i], retc)
				end
				if #signature > 2 then
					-- multiple versions so delete the original name
					module[luafunc] = nil
				end
			else
				-- nested submodule
				wrapmodule(module[luafunc], signature)
			end
		elseif type(signature) == "number" then
			-- no return count specified; defaults to 1
			module[luafunc] = wrapfunc(module[luafunc], signature)
		else
			-- TODO: call closure?
		end
	end
	return module
end

function wrapglobals(globalenv)
	return wrapmodule(globalenv, {
		-- assert = nil, -- NOWRAP: returns all args
		error = { 2, 0 },
		loadstring = 1, -- TODO: change to 2 and pass in function or file name
		print = { 1, 0 }, -- TODO: allow varargs in some structured way?
		require = 1,
		tostring = 1,
		type = 1,
		getmetatable = 1,
		setmetatable = 2,
		-- pcall = nil,	-- NOWRAP: returns all args
		-- xpcall = nil,-- NOWRAP: returns all args
		bit = {
			band = 2,
			bor = 2,
			bxor = 2,
			bnot = 1,
			lshift = 2,
			rshift = 2
		},
		math = {
			abs = 1,
			ceil = 1,
			floor = 1,
			max = 2,
			min = 2,
			random = {0, 1, 2, 1},
			randomseed = {1, 0},
		},
		os = {
			exit = { 1, 0 }, -- technically, never returns
			time = 0,
		},
		string = {
			-- format = nil, -- TODO: returns 1, but could take any number
			gsub = { 2, 2 },
			sub = 3
		},
		table = {
			concat = 2,
			insert = { 2, 0 },
			push = { 1, 0 }
		}
	})
end

local PREFIX = "Lua"
function maplua(globalenv, lua)
	for name, val in pairs(lua) do
		local path = PREFIX .. "." .. name
		globalenv[path] = val
		if type(val) == "table" then
			for fname, fval in pairs(val) do
				local path = path .. "." .. fname
				globalenv[path] = fval
			end
		end
	end
	return globalenv
end

function inject(target, source)
	for name, val in pairs(source) do
		if name == "_G" then
			-- skip self-referential _G
		elseif type(val) == "table" and name ~= "package" then -- FIXME
			target[name] = inject({}, val)
		else
			target[name] = val
		end
	end
	return target
end

return module
