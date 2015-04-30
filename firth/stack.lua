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
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


--! @cond
local table = require "table"

local mt
local stack = {
	__FIRTH_INTERNAL__ = "   <stack>" -- used for stacktraces
}

-- throw if stack is too short for operation
local function assertsize(st, min, msg)
	local __FIRTH_DUMPTRACE__ = true -- used for stacktraces
	assert(min <= st.height, msg)
end
--! @endcond


--! Pushes an item onto the stack.
--! @param val value to push onto the stack
function stack:push(val)
	local top = self.height + 1
	rawset(self, top, val)
	self.height = top
end

function stack:pushv(...)
	local args = {...}
	for _, arg in ipairs(args) do
		self:push(arg)
	end
end

--! Pops an item off the stack
--! @return the former top stack item.
function stack:pop()
	assertsize(self, 1, "UNDERFLOW")
	local val = rawget(self, self.height)
	self:drop()
	return val
end

--! Peeks at the top item, non-destructively.
--! @return a copy of the top of the stack, without popping it.
function stack:top()
	assertsize(self, 1, "STACK EMPTY")
	return rawget(self, self.height)
end

--! Pushes a copy of the top stack entry.
function stack:dup()
	assertsize(self, 1, "STACK EMPTY")
	self:push(self:top())
end

--! Removes the top stack item.
function stack:drop()
	assertsize(self, 1, "UNDERFLOW")
	local top = self.height
	rawset(self, top, 0)
	self.height = top - 1
end

--! Removes all items from the stack.
function stack:clear()
	local top = self.height
	for i = top, 1, -1 do rawset(self, i, 0) end
	self.height = 0
end

--! Swaps the location of the two top items.
function stack:swap()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = self.height
	local prev = top - 1
	self[top], self[prev] = self[prev], self[top]
end

--! Pushes a copy of the second item from the top.
function stack:over()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = self.height
	self:push(rawget(self, top-1))
end

--! Rotates the top 3 stack elements downward.
function stack:rot()
	assertsize(self, 3, "INSUFFICIENT HEIGHT")
	local top = self.height
	local prev, second = top - 1, top - 2
	self[second], self[prev], self[top] = self[prev], self[top], self[second]
end

--! Rotates the top 3 stack elements upward.
function stack:revrot()
	assertsize(self, 3, "INSUFFICIENT HEIGHT")
	local top = self.height
	local prev, second = top - 1, top - 2
	self[second], self[prev], self[top] = self[top], self[second], self[prev]
end

--! Removes the second item from the top.
function stack:nip()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = self.height
	local prev = top - 1
	rawset(self, prev, rawget(self, top))
	self:drop()
end

--! Swaps the top two items, and pushes a copy of the former top item.
function stack:tuck()
	self:swap()
	self:over()
end

--! Pushes a copy of the specified item.
--! @param idx zero-based offset from the top of the stack of item to duplicate.
function stack:pick(idx)
	assertsize(self, idx + 1, "INSUFFICIENT HEIGHT")
	local top = self.height
	self:push(rawget(self, top - idx))
end

--! Removes the item at the given index and pushes it back onto the stack.
--! @param idx offset of item to duplicate from the top of the stack.
function stack:roll(idx)
	assertsize(self, idx + 1, "INSUFFICIENT HEIGHT")
	local top = self.height
	local tmp = rawget(self, top - idx)
	for i = top-idx, top-1 do
		rawset(self, i, rawget(self, i+1))
	end
	rawset(self, top, tmp)
end

function stack:__tostring()
	local height = self.height
	local buf = {}
	for i = 1, height do
		buf[i] = tostring(self[i])
	end

	return "["..table.concat(buf, ' ').."]"
end

function stack:__itr()
	return function(height, current)
				if current < height then
					current = current + 1
					return current, self[current]
				end
			end, self.height, 0
end


-- set up metatable and library table --
--! @cond
mt = stack
mt.__index = mt
stack = {}
--! @endcond

--! stack constructor.
--! <p>Example usage:</p>
--! <pre>
--! local stack = require 'stack'
--! local st = stack.new()
--! st:push(1)
--! st:push(2)
--! st:push(3)
--! print(st:pop(), st:pop(), st:pop())
--! -- prints: 3	2	1
--! </pre>
--! @return a newly initialized stack object.
function stack.new()
	local s = setmetatable({ height = 0 }, mt)
	for i = 32,1,-1 do s[i] = 0 end -- poke in some null data to pre-reserve array 
	return s
end

return stack
