--------------------------------------------------------------------------------
--! @file
--! @brief Simple testing framework for Firth language components.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2021 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local io = require 'io'
local output = io.output()
local table = require 'table'


local failures = 0
local mt = { insert = table.insert }
mt.__index = mt
local messages = setmetatable({}, mt)

local function try(test, ...)
	local succ, msg = pcall(test, ...)
	if not succ then
		failures = failures + 1
		if msg then messages:insert(msg) end
		output:write 'E'
	else
		output:write '.'
	end
end

local function failed(msg)
	output:write('E')
	messages:insert(msg)
	failures = failures + 1
end

local function dotests(path)
	local tests, err = loadfile(path)
	if tests and not err then
		success, tests = pcall(tests)
		if success then
			for _, test in ipairs(tests) do
				try(test)
			end
		else
			failed(tests)
		end
	else
		local me = ""
		if err:sub(1, 11) == "cannot open" then
			me = debug.getinfo(dotests, "S").source..": dotests(): "
			if me:sub(1, 1) == '@' then me = me:sub(2) end
		end
		failed(me..err)
	end
	output:write('\n')
end


-- export globally so it's accessible from tests.conf
function testlist(list)
	for _, path in ipairs(list) do dotests(path) end
end

local succ, msg = pcall(dofile, "test/tests.conf")
if not succ then failed(msg) end

if failures > 0 then
	output:write(string.format("\n%d failed tests.\n", failures))
	for _, msg in ipairs(messages) do
		output:write(string.format("%s\n", msg))
	end
	os.exit(failures)
end
