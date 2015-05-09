local create, yield, resume = coroutine.create, coroutine.yield, coroutine.resume

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

-- redundant, but possibly semantically useful	
local function push(x, ...)
	return x, ...
end

local function drop(tos, ...)
	return ...
end

local function top(tos, ...)
	return tos
end

local function shove(i, x, tos, ...)
	if i == 0 then return x, tos, ... end
	return shovefilter(0, i, x, ...)
end

local function yank(i, tos, ...)
	if i == 0 then return ... end
	return yankfilter(0, i, tos, ...)
end

local function peek(i, tos, ...)
	if i == 0 then return tos end
	return (select(i+1, tos, ...))
end

local height = count

-- stack method coroutines / continuations --

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

-- export
firth = firth or {}
firth.fstack = {
	new = new;

	push = push, drop = drop, top = top;
	shove = shove, yank = yank, peek = peek;

	height = height;
}
return firth.fstack
