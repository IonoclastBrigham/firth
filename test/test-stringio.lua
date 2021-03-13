--------------------------------------------------------------------------------
--! @file
--! @brief Text io and manipulation routines test module.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2021 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution in the file LICENSE; if not, you may find it online at
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local stringio = require 'firth/stringio'

local table = require 'table'


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
		local tok
		for i = 1, 2 do
			tok, str = stringio.nexttoken(str)
			assert(i == stringio.tonumber(tok),
				string.format("Incorrect token value parsed: '%s'", tok))
		end
		for i = 3, 4 do
			tok, str = stringio.nexttoken(str, ':')
			assert(i == stringio.tonumber(tok),
				string.format("Incorrect token value parsed: '%s'", tok))
		end
		assert(str == ":::", "Expected ':::' after last token; got '"..str.."'")
	end,

	function()
		local nested = "(I'd like to talk to you about a thing (you know... the thing))"
		local str = "  \t"..nested.."123"
		local tok
		tok, str = stringio.matchtoken(str, "%b()")
		assert(tok == nested,
			string.format("Incorrect token value parsed: '%s'", tok))
		assert(str == "123", "Expected '123' after last token; got '"..str.."'")
		tok, str = stringio.matchtoken(str, '2')
		assert(tok == '2',
			string.format("Incorrect token value parsed: '%s'", tok))
		assert(str == "3", "Expected '3' after last token; got '"..str.."'")
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
