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
--! @endcond


--! Pushes an item onto the stack.
--! @param val value to push onto the stack
function stack:push(val)
	local top = self.height + 1
	rawset(self, top, val)
	self.height = top
end

--! Pops an item off the stack
--! @return the former top stack item.
function stack:pop()
	local val = rawget(self, self.height)
	self:drop()
	return val
end

--! Peeks at the top item, non-destructively.
--! @return a copy of the top of the stack, without popping it.
function stack:top()
	return rawget(self, self.height)
end

--! Pushes a copy of the top stack entry.
function stack:dup()
	if self.height < 1 then return end
	self:push(self:top())
end

--! Removes the top stack item.
function stack:drop()
	local top = self.height
	if top < 1 then return end
	rawset(self, top, nil)
	self.height = top - 1
end

--! Removes all items from the stack.
function stack:clear()
	local top = self.height
	for i = top, 1, -1 do rawset(self, i, nil) end
	self.height = 0
end

--! Swaps the location of the two top items.
function stack:swap()
	local top = self.height
	if top < 2 then return end
	local prev = top - 1
	self[top], self[prev] = self[prev], self[top]
end

--! Pushes a copy of the second item from the top.
function stack:over()
	local top = self.height
	if top < 2 then return end
	self:push(rawget(self, top-1))
end

--! Rotates the top 3 stack elements downward.
function stack:rot()
	local top = self.height
	if top < 3 then return end
	self[top-2], self[top-1], self[top] = self[top-1], self[top], self[top-2]
end

--! Rotates the top 3 stack elements upward.
function stack:revrot()
	local top = self.height
	if top < 3 then return end
	self[top-2], self[top-1], self[top] = self[top], self[top-2], self[top-1]
end

--! Removes the second item from the top.
function stack:nip()
	local top = self.height
	if top < 2 then return end
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
	local top = self.height
	if (idx < 0) or (idx >= top) then return end
	self:push(rawget(self, top - idx))
end

--! Removes the item at the given index and pushes it back onto the stack.
--! @param idx offset of item to duplicate from the top of the stack.
function stack:roll(idx)
	local top = self.height
	if (idx < 1) or (idx >= top) then return end
	local tmp = rawget(self, top - idx)
	for i = top-idx, top-1 do
		rawset(self, i, rawget(self, i+1))
	end
	rawset(self, top, tmp)
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
	local s = { height = 0 }
	return setmetatable(s, mt)
end

return stack