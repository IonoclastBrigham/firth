--------------------------------------------------------------------------------
--! @file
--! @brief Fast Lua Interface - launguage bindings for :Firth.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021 Brigham Toskin
--!
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution in the file LICENSE; if not, you may find it online at
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
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

function lua0(xt, ...)
	return xt(), ...
end

function lua1(xt, p1, ...)
	return xt(p1), ...
end

function lua2(xt, p2, p1, ...)
	return xt(p1, p2), ...
end

function lua3(xt, p3, p2, p1, ...)
	return xt(p1, p2, p3), ...
end

function lua4(xt, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4), ...
end

function lua5(xt, p5, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4, p5), ...
end

function lua6(xt, p6, p5, p4, p3, p2, p1, ...)
	return xt(p1, p2, p3, p4, p5, p6), ...
end

local dispatch = { lua1, lua2, lua3, lua4, lua5, lua6 }
dispatch[0] = lua0

function wrapfunc(f, argc)
	local luafunc = dispatch[argc]
	return function(...)
		return luafunc(f, ...)
	end
end

function wrapmodule(module, defs)
	for k, v in pairs(defs) do
		if type(v) == "table" then
			wrapmodule(module[k], v)
		elseif type(v) == "number" then
			module[k] = wrapfunc(module[k], v)
		else
			-- TODO: call closure?
		end
	end
	return module
end

function wrapglobals(globalenv)
	return wrapmodule(globalenv, {
		assert = 2,
		error = 1,
		loadstring = 1,
		print = 1,		-- TODO
		require = 1,
		tostring = 1,
		type = 1,
		pcall = nil,	-- TODO
		xpcall = nil,	-- TODO
		os = {
			exit = 1
		},
		string = {
			format = nil, -- TODO: vararg; function?
			gsub = 2,
			sub = 3
		},
		table = {
			concat = 2,
			insert = 2,
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
