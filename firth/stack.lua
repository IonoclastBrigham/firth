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
local table = require "table"

local mt
local stack = {}

-- throw if stack is too short for operation
local function assertsize(st, min, msg)
	local __FIRTH_DUMPTRACE__ = true
	assert(min <= #st, msg) -- TODO: use st.height when implemented
end
--! @endcond


--! Pushes an item onto the stack.
--! @param val value to push onto the stack
function stack:push(val)
	table.insert(self, val)
end

--! Pops an item off the stack
--! @return the former top stack item.
function stack:pop()
	assertsize(self, 1, "UNDERFLOW")
	return table.remove(self)
end

--! Peeks at the top item, non-destructively.
--! @return a copy of the top of the stack, without popping it.
function stack:top()
	assertsize(self, 1, "STACK EMPTY")
	return self[#self]
end

--! Pushes a copy of the top stack entry.
function stack:dup()
	assertsize(self, 1, "STACK EMPTY")
	self:push(self[#self])
end

--! Removes the top stack item.
function stack:drop()
	assertsize(self, 1, "UNDERFLOW")
	self[#self] = nil
end

--! Removes all items from the stack.
function stack:clear()
	for i in next, self do rawset(self, i, nil) end
end

--! Swaps the location of the two top items.
function stack:swap()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = #self
	self[top], self[top-1] = self[top-1], self[top]
end

--! Pushes a copy of the second item from the top.
function stack:over()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = #self
	self:push(self[top-1])
end

--! Rotates the top 3 stack elements downward.
function stack:rot()
	assertsize(self, 3, "INSUFFICIENT HEIGHT")
	local top = #self
	self[top-2], self[top-1], self[top] = self[top-1], self[top], self[top-2]
end

--! Rotates the top 3 stack elements upward.
function stack:revrot()
	assertsize(self, 3, "INSUFFICIENT HEIGHT")
	local top = #self
	self[top-2], self[top-1], self[top] = self[top], self[top-2], self[top-1]
end

--! Removes the second item from the top.
function stack:nip()
	assertsize(self, 2, "INSUFFICIENT HEIGHT")
	local top = #self
	table.remove(self, top-1)
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
	self:push(self[#self - idx])
end

--! Removes the item at the given index and pushes it back onto the stack.
--! @param idx offset of item to duplicate from the top of the stack.
function stack:roll(idx)
	assertsize(self, idx + 1, "INSUFFICIENT HEIGHT")
	self:push(table.remove(self, idx))
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
	local s = {}
	return setmetatable(s, mt)
end

return stack