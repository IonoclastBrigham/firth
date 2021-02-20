local select = select

local setfenv = setfenv or require 'compat.compat_env'.setfenv

local module = {}
setfenv(1, module)

-- util functions --

local function count(...)
	return select("#", ...)
end

local function shovefilter(n, i, x, ...)
	if i == n then return x, ... end
	return (...), shovefilter(n+1, i, x, select(2, ...))
end

local function yankfilter(n, i, tos, ...)
	if i == n then return ... end
	if count(...) > 0 then return tos, yankfilter(n+1, i, ...) end
end

-- in-thread stack manipulation primitives --

-- seems redundant, but needed for threading compiled lua code
function push(x, ...)
	return x, ...
end

-- (probably mostly for lua code)
function top(tos, ...)
	return tos
end

function dup(tos, ...)
	return tos, tos, ...
end

function over(tos, _2nd, ... )
	return _2nd, tos, _2nd, ...
end

function drop(tos, ...)
	return ...
end

function clear(...)
	return
end

function swap(tos, _2nd, ...)
	return _2nd, tos, ...
end

function rot(tos, _2nd, _3rd, ... )
	return _3rd, tos, _2nd, ...
end

module['-rot'] = function(tos, _2nd, _3rd, ... )
	return _2nd, _3rd, tos, ...
end

function pick(idx, ...)
	return select(idx, ...), ...
end

function shove(i, x, tos, ...)
	if i == 0 then return x, tos, ... end
	return shovefilter(0, i, x, ...)
end

function yank(i, tos, ...)
	if i == 0 then return ... end
	return yankfilter(0, i, tos, ...)
end

function peek(i, tos, ...)
	if i == 0 then return tos end
	return (select(i+1, tos, ...))
end

function chop(n, tos, ...)
	if n == 1 then return ... end
	return select(n, ...)
end

function height(...)
	return count(...), ...
end

function c_from(...)
	return cstack:pop(), ...
end

function to_c(tos, ...)
	cstack:push(tos)
	return ...
end

return module

-- stack method coroutines / continuations --

--[[
local function pushs(x, ...)
	local continuation, nx = yield()
	return continuation(nx, push(x, ...))
end

local function pops(_, ...)
	local continuation, x = yield(top(...))
	return continuation(x, drop(...))
end

local function shoves(_, ...)
	local continuation, x = yield()
	return continuation(x, shove(...))
end

local function yanks(x, ...)
	local continuation, nx = yield((select(x+1, ...)))
	return continuation(nx, yankfilter(0, x, ...))
end

local function peeks(x, ...)
	local continuation, x = yield((select(x+1, ...)))
	return continuation(x, ...)
end

local function unpacks(x, ...)
	local continuation, x = yield(...)
	return continuation(x, ...)
end

local function clears(x, ...)
	local continuation, x = yield()
	return continuation(x)
end

local function heights(x, ...)
	local continuation, x = yield(count(...))
	return continuation(x, ...)
end

-- c'tor --

local function init(...)
	local continuation, x = yield()
	return continuation(x, ...)
end

local function new(...)
	local stack = create(init)
	resume(stack, ...)

	return {
		push = function(x) resume(stack, pushs, x) end,
		pop = function()
			local _, x = resume(stack, pops)
			return x
		end,
		shove = function(i, x)
			shovei, shovex = i, x -- load shove registers
			resume(stack, shoves, nil)
		end,
		yank = function(i)
			local _, x = resume(stack, yanks, i)
			return x
		end,
		peek = function(i)
			local _, x = resume(stack, peeks, i)
			return x
		end,
		unpack = function() return select(2, resume(stack, unpacks)) end,
		clear = function() resume(stack, clears) end,
		height = function()
			local _, h = resume(stack, heights)
			return h
		end,
	}
end
--]]
