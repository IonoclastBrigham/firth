--------------------------------------------------------------------------------
--! @file
--! @brief Bitwise operations module for Lua 5.2+.
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
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------

local bit = bit or bit32

if not bit then
	bit = {}
	function bit.band(a, b)
		return a & b
	end

	function bit.bor(a, b)
		return a | b
	end

	function bit.bxor(a, b)
		return a ^ b
	end

	function bit.bnot(x)
		return ~x
	end

	function bit.lshift(x, n)
		return x << n
	end

	function bit.rshift(x, n)
		return x >> n
	end
end

return bit
