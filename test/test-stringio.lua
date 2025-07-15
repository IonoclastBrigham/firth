--------------------------------------------------------------------------------
--! @file
--! @brief Text io and manipulation routines test module.
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


local table = require 'table'

local stringio = require 'firth.stringio'


return {

	function()
		local toks = {"Hello,", "World!"}
		local string = table.concat(toks, ' ')
		local i = 1
		for tok in stringio.tokens(string) do
			assert(tok == toks[i], "Token mismatch: "..tok..", "..toks[i])
			i = i + 1
		end
	end,

	function()
		local toks = stringio.split "this.should produce\tan array of-@#$_SIX \t \nstrings"
		assert(#toks == 6, "Incorrect number of tokens returned")
	end,

	function()
		local str = "\t1 2   \t 3:4::::"
		local tok, parsepos = "", 1
		for i = 1, 2 do
			tok, parsepos = stringio.nexttoken(str, nil, parsepos)
			assert(i == stringio.tonumber(tok),
				string.format("Incorrect token value parsed: '%s'", tok))
		end
		for i = 3, 4 do
			tok, parsepos = stringio.nexttoken(str, ':', parsepos)
			assert(i == stringio.tonumber(tok),
				string.format("Incorrect token value parsed: '%s'", tok))
		end
		test.assert_eq(str:sub(parsepos), "::::", "Should leave remaining unconsumed string suffix")
	end,

	function()
		local nested = "(I'd like to talk to you about a thing (you know... the thing))"
		local str = "  \t"..nested.."123"

		local tok, parsepos = stringio.matchtoken(str, "%b()")
		test.assert_eq(tok, nested, "Should parse out entire nested parentheses.")

		tok = stringio.matchtoken(str, ".+", parsepos)
		test.assert_eq(tok, "123", "Remaining string after nested parentheses should be '123'.")

		tok, parsepos = stringio.matchtoken(str, '2')
		test.assert_eq(tok, '2', "Should find substring")
		test.assert_eq(str:sub(parsepos), "3", "Expected '3' after last token")
	end,

	function()
		assert(stringio.tonumber('0') == 0, "Conversion to number failed")
		assert(stringio.tonumber('1.') == 1.0, "Conversion to number failed")
		assert(stringio.tonumber('.1') == 0.1, "Conversion to number failed")
		assert(stringio.tonumber(' 3.14159 ') == 3.14159, "Conversion to number failed")
		assert(stringio.tonumber('-1.23456E-5') == -1.23456E-5, "Conversion to number failed")

		local t = {s = "2.718281828459045"}
		local mt = {}
		function mt:__tostring() return self.s end
		mt.__index = mt
		setmetatable(t, mt)
		assert(stringio.tonumber(t) == 2.718281828459045, "Conversion to number failed")

		assert(stringio.tonumber('zero') == nil, "Conversion to number failed to fail")
		assert(stringio.tonumber('1.0.') == nil, "Conversion to number failed to fail")
		assert(stringio.tonumber('PI=3.14159') == nil, "Conversion to number failed to fail")
		assert(stringio.tonumber('123 hello') == nil, "Conversion to number failed to fail")
		assert(stringio.tonumber('') == nil, "Conversion to number failed to fail")
	end,

}
