--------------------------------------------------------------------------------
--! @file
--! @brief Stack class test module.
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


local stack = require 'firth/stack'

local st
local initialcount = 5

-- prints stack contents with error message
local function assert(bool, msg, level)
	level = level or 2
	if not bool then
		error(msg.."\nstack: "..table.concat(st, ', '), level)
	end
end

local function assertstack(name, ...)
	local items = {...}
	assert(#items == st.height,
		string.format("%s(): stack height %d (expected %d)",
			name, st.height, #items),
		3)
	for i = 1, st.height do
		assert(st[i] == items[i],
			string.format("%s(): stack[%d] == %s (expected %s)",
				name, i, tostring(st[i]), tostring(items[i])),
			3)
	end
end

return {

	function()
		st = stack.new() -- ()
		assert(st, "Error creating new stack")
		assert(st.height == 0, "Error creating new stack")
	end,

	function()
		for i = 1, initialcount do
			st:push(i)
			assert(st[st.height] == i, "Error pushing "..i.." onto stack")
		end
		assertstack("push", 1, 2, 3, 4, 5)
	end,

	function()
		local top = st.height
		local topitem = st:pop()
		assertstack("pop", 1, 2, 3, 4)
		assert(topitem == top, "pop() returned incorrect TOS val: "..topitem)
	end,

	function()
		local top = st.height
		st:drop()
		assertstack("drop", 1, 2, 3)
	end,

	function()
		local top = st.height
		local topitem = st:top()
		assertstack("top", 1, 2, 3)
		assert(topitem == top, "top() returned incorrect TOS val: "..top)
	end,

	function()
		local top = st.height
		st:dup()
		assertstack("dup", 1, 2, 3, 3)
		local topitem = st[st.height]
		local previtem = st[st.height - 1]
		st[st.height] = 4 -- sets up for testing swap()
	end,

	function()
		local top = st.height
		st:swap()
		assertstack("swap", 1, 2, 4, 3)
	end,

	function()
		local top = st.height
		st:over()
		assertstack("over", 1, 2, 4, 3, 4)
	end,

	function()
		local top = st.height
		st:rot()
		assertstack("rot", 1, 2, 3, 4, 4)
		st[top] = 5 -- replaces dup'ed val for testing nip()
	end,

	function()
		local top = st.height
		st:nip()
		assertstack("nip", 1, 2, 3, 5)
	end,

	function()
		local top = st.height
		st:tuck()
		assertstack("tuck", 1, 2, 5, 3, 5)
	end,

	function()
		local top = st.height
		st:pick(2)
		assertstack("pick", 1, 2, 5, 3, 5, 5)
	end,

	function()
		local top = st.height
		st:roll(2)
		assertstack("roll", 1, 2, 5, 5, 5, 3)
	end,

	function()
		local top = st.height
		local a, b, c = st[top], st[top-1], st[top-2]
		st:revrot()
		assertstack("-rot", 1, 2, 5, 3, 5, 5)
	end,

	function()
		local top = st.height
		st:push(nil)
		assert(st.height == top + 1, "push(nil) did not increment size")
		assert(st:pop() == nil, "pop() didn't properly return nil")
		assert(st.height == top, "pop() didn't properly return nil")
	end,

	function()
		st:clear() -- ()
		assert(st.height == 0, "clear() did not empty stack")
	end,

	function()
		st:pushv(1, 2, 3, 4)
		assertstack("pushv", 1, 2, 3, 4)
		st:clear()
	end,

	function()
		st:push(nil)
		st:push(123.456)
		st:push(nil)
		assert(st.height == 3, "didn't push nils")

		-- we can't use assertstack() because it will count nils wrong
		assert(st:pop() == nil, "didn't push nil correctly")
		assert(st:pop() == 123.456, "didn't push nil correctly")
		assert(st:pop() == nil, "didn't push nil correctly")
	end,
}
