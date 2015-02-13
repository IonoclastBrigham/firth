--------------------------------------------------------------------------------
--! @file stack.lua
--! @brief Stack class for Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015 Brigham Toskin
--! 
--! <p>This file is part of the Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--------------------------------------------------------------------------------


--! @cond
local mt = {}
local stack = {}
--! @endcond


--! stack constructor.
--! @return a newly initialized stack object.
function stack.new()
	local s = {}
	return setmetatable(s, mt)
end

return stack