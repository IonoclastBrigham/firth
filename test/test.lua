--------------------------------------------------------------------------------
--! @file
--! @brief Simple testing framework for Firth language components.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2025 Brigham Toskin
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
local stdout, stderr = io.stdout, io.stderr
local table = require 'table'
local setfenv = setfenv or require 'compat.compat_env'.setfenv -- Lua@5.2+

local fli = require 'firth.fli'
local stringio = require 'firth.stringio'


-- internal state
local failcount = 0
local mt = { insert = table.insert }
mt.__index = mt
local messages = setmetatable({}, mt)

PRINT_ERRS = false -- EXPORTED; disable default :Firth error printing

-- utilities
local function failed(msg)
	stdout:write('E')
	messages:insert(msg)
	failcount = failcount + 1
end

local function try(test, ...)
	local oldfailed = failcount
	local succ, msg = pcall(test, ...)
	if not succ then
		failed(msg)
	elseif oldfailed == failcount then
		stdout:write '.'
	end
end

-- testcase helpers - export globally so it's accessible from test cases
test = {} -- exported test module

test.assert_eq = function(actual, expected, msg)
	if actual ~= expected then
		msg = (msg or 'Assertion failed!')
			.. '\n   Expected: ' .. tostring(stringio.quote(expected))
			.. '\n   Actual  : ' .. tostring(stringio.quote(actual))
		failed(msg)
	end
end

test.assert_true = function(actual, msg)
	return test.assert_eq(actual, true, msg or 'Value should be true')
end

-- top level test harness
local function dotests(path)
	stdout:write(string.format("\nRunning tests in %s: ", path))
	local loadtests, err = loadfile(path)
	if loadtests and not err then
		-- give each suite its own environment
		local testenv = fli.inject({}, _G)
		testenv._G = testenv
		setfenv(loadtests, testenv)

		local oldfailed = failcount
		local success, tests = pcall(loadtests)
		if success then
			for _, test in ipairs(tests) do
				try(test)
			end
			if failcount == oldfailed then
				stdout:write(" ✅")
			else
				stdout:write(" ❌")
			end
		else
			failed(tests)
			stdout:write(" ❌")
		end
	else
		local me = ""
		if err:sub(1, 11) == "cannot open" then
			me = debug.getinfo(dotests, "S").source .. ": dotests(): "
			if me:sub(1, 1) == '@' then me = me:sub(2) end
		end
		failed(me .. err)
	end
end

-- export globally so it's accessible from tests.conf
function testlist(list)
	for _, path in ipairs(list) do dotests(path) end
	stdout:write('\nDONE!\n')
	stdout:flush()
end

local succ, msg = pcall(dofile, "test/tests.conf")
if not succ then failed(msg) end

if failcount > 0 then
	stderr:write(string.format("\n%d failed test(s).\n", failcount))
	for _, msg in ipairs(messages) do
		stderr:write(string.format("❌ %s\n", msg))
	end
	os.exit(failcount)
else
	stdout:write("\n✅ All tests passed!\n")
end
