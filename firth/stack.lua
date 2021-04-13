--------------------------------------------------------------------------------
--! @file
--! @brief Stack class for :Firth language.
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


--! @cond
local rawget, rawset = rawget, rawset
local select = select
local table = table

local stringio = require "firth.stringio"
require "firth.luex"


local stack = {
	__FIRTH_INTERNAL__ = "   <stack>" -- used for stacktraces
}

-- throw if stack is too short for operation
local function assertsize(st, min, msg)
	return assert(min <= rawget(st, "height"), msg)
end
--! @endcond


--! Pushes an item onto the stack.
--! @param val value to push onto the stack
function stack:push(val)
	local top = self.height + 1
	rawset(self, top, val)
	self.height = top
end

local function pushv(self, ...)
	if select("#", ...) == 0 then return end
	self:push((...))
	return pushv(self, select(2, ...))
end
stack.pushv = pushv

--! Pops an item off the stack
--! @return the former top stack item.
function stack:pop()
	local val = rawget(self, self.height)
	self:drop() -- assert happens here
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
	if height == 0 then
		buf[1] = '∅'
	else
		for i = 1, height do
			buf[i] = tostring(stringio.quote(self[i]))
		end
	end

	return "[ "..table.concat(buf, ' ').." ]"
end

-- TODO: replace with standard `__ipairs`?
function stack:__itr()
	return function(_, current)
		current = current - 1
		if current > 0 then
			return current, rawget(self, current)
		end
	end, nil, self.height + 1
end

function stack:__len()
	return self.height
end


-- set up metatable and library table --
--! @cond
local mt = stack
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
	return setmetatable({ height = 0 }, mt)
end

return stack
