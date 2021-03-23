--------------------------------------------------------------------------------
--! @file
--! @brief Fast Lua Interface - launguage bindings for :Firth.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021 Brigham Toskin
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


local pairs = pairs
local print = print
local select = select
local setfenv = setfenv or require 'compat.compat_env'.setfenv
local string = string
local type = type

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
}
dispatch[0] = { lua0_1, lua0_2, lua0_3 }
dispatch[0][0] = lua0_0
dispatch[1][0] = lua1_0
dispatch[2][0] = lua2_0
dispatch[3][0] = lua3_0

--! @endcond


--! Wraps a Lua function for use as a :Firth word.
--!
--! @param f    {function} the Lua function to wrap.
--! @param argc {number}   number of arguments to pull from :Firth stack.
--! @param ret  {number}   number of returns from `f`; defaults to `1`.
--! @return                `ret` values returned from `f()`.
function wrapfunc(f, argc, ret)
	ret = ret or 1
	local luafunc = dispatch[argc][ret]
	return function(...)
		return luafunc(f, ...)
	end
end

function wrapmodule(module, defs)
	for k, v in pairs(defs) do
		if type(v) == "table" then
			if #v == 2 then
				local argc, ret = v[1], v[2]
				module[k] = wrapfunc(module[k], argc, ret)
			else
				-- nested submodule
				wrapmodule(module[k], v)
			end
		elseif type(v) == "number" then
			-- no return count specified; defaults to 1
			module[k] = wrapfunc(module[k], v)
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
		loadstring = 1,
		print = { 1, 0 }, -- TODO: allow varargs in some structured way?
		require = 1,
		tostring = 1,
		type = 1,
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
			floor = 1
		},
		os = {
			exit = { 1, 0 } -- technically, never returns
		},
		string = {
			-- format = nil, -- TODO: returns 1, but could take any number
			gsub = { 2, 2 },
			sub = 2
		},
		table = {
			concat = 2,
			insert = { 2, 0}
		}
	})
end

local PREFIX = "Lua"
function maplua(globalenv, lua)
	for name, val in pairs(lua) do
		local path = PREFIX.."."..name
		globalenv[path] = val
		if type(val) == "table" then
			for fname, fval in pairs(val) do
				local path = path.."."..fname
				globalenv[path] = fval
			end
		end
	end
	return globalenv
end

function inject(globalenv, module)
	for name, val in pairs(module) do
		if name == "_G" then
			-- skip self-referential _G
		elseif type(val) == "table" and name ~= "package" then -- FIXME
			globalenv[name] = inject({}, val)
		else
			globalenv[name] = val
		end
	end
	return globalenv
end


return module
