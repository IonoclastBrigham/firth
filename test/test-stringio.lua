local stringio = require 'lib/stringio'

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
		assert(#str == 0, "Expected string to be empty after last token")
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