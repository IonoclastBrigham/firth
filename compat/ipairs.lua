--------------------------------------------------------------------------------
--! @file
--! @brief Adds support for 5.2 style __ipairs metamethods in Lua 5.1/JIT.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2025 Brigham Toskin
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


if tonumber(_VERSION:sub(5)) < 5.2 then
	-- Lua@5.1/JIT
	local ipairs51 = ipairs
	ipairs = function(t)
		local mt = getmetatable(t)
		if mt and mt.__ipairs then
			-- local iter = mt.__ipairs(t)
			-- if type(iter) == "function" then
			-- 	return iter, t, 0
			-- else
			-- 	return ipairs51(t)
			-- end
			return mt.__ipairs(t)
		else
			return ipairs51(t)
		end
	end
end
return ipairs
