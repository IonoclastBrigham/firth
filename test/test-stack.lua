local stack = require 'firth/stack'

local st
local initialcount = 5

return {

	function()
		st = stack.new() -- ()
		assert(st, "Error creating new stack")
	end,

	function()
		for i = 1, initialcount do
			st:push(i)
			assert(st[#st] == i, "Error pushing "..i.." onto stack")
		end -- (1, 2, 3, 4, 5)
		assert(#st == initialcount, "Error pushing "..initialcount.." items onto stack.")
	end,

	function()
		local top = st:pop() -- (1, 2, 3, 4)
		assert(top == initialcount, "pop() returned incorrect TOS val: "..top)
		assert(#st == initialcount - 1, "pop() did not decrement size")
	end,

	function()
		st:drop() -- (1, 2, 3)
		assert(#st == initialcount - 2, "drop() did not decrement size")
	end,

	function()
		local top = st:top() -- (1, 2, 3)
		assert(top == initialcount - 2, "top() returned incorrect TOS val: "..top)
		assert(#st == initialcount - 2, "top() did alter size")
	end,

	function()
		st:dup() -- (1, 2, 3, 3)
		local top = st[#st]
		local next = st[#st - 1]
		assert(top == next, "dup() did not duplicate correct val: "..top)
		assert(#st == initialcount - 1, "dup() did not leave stack correct size")
		st[#st] = nil -- (1, 2, 3) cleans up dup'ed val for testing swap()
	end,

	function()
		local len = #st
		st:swap() -- (1, 3, 2)
		assert(len == #st, "swap() did alter size")
		assert(st[#st] == (st[#st - 1] - 1),
			"swap() did not properly swap top items: "..st[#st]..', '..st[#st - 1])
	end,

	function()
		local len = #st
		st:over() -- (1, 3, 2, 3)
		assert(#st == len + 1, "over() did not increment size")
		assert(st[len + 1] == st[len - 1], "over() did not properly dup second from top item")
	end,

	function()
		local len = #st
		st:rot() -- (1, 2, 3, 3)
		assert(len == #st, "rot() did alter size")
		assert(st[len] == st[len - 1], "rot() did not rotate stack")
		st[#st] = nil -- (1, 2, 3) cleans up dup'ed val for testing nip()
	end,

	function()
		local len = #st
		st:nip() -- (1, 3)
		assert(#st == len - 1, "nip() did not decrement size")
	end,

	function()
		local len = #st
		st:tuck() -- (3, 1, 3)
		assert(#st == len + 1, "tuck() did not increment size")
		assert(st[len + 1] == st[len - 1], "tuck() did not swap and copy correctly")
	end,

	function()
		local len = #st
		st:pick(2) -- (3, 1, 3, 3)
		assert(#st == len + 1, "pick() did not increment size")
		assert(st[len + 1] == st[len - 2], "pick() did not dup correctly: "..st[len + 1]..', '..st[len - 2])
	end,

	function()
		local len = #st
		st:roll(2) -- (3, 3, 3, 1)
		assert(len == #st, "roll() did alter size")
		assert(st[1] == 3, "roll() did not grab and shift correctly")
		assert(st[2] == 3, "roll() did not grab and shift correctly")
		assert(st[3] == 3, "roll() did not grab and shift correctly")
		assert(st[4] == 1, "roll() did not grab and shift correctly")
	end,

	function()
		st:clear() -- ()
		assert(#st == 0, "clear() did not empty stack")
	end,
}