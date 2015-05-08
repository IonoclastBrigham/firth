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

-- stack methods --

local function push(x, ...)
	local continuation, nx = yield()
	return continuation(nx, x, ...)
end

local function pop(_, ...)
	local continuation, x = yield((...))
	return continuation(x, select(2, ...))
end

local function shove(_, ...)
	local continuation, x = yield()
	return continuation(x, shovefilter(0, ...))
end

local function yank(x, ...)
	local continuation, nx = yield((select(x+1, ...)))
	return continuation(nx, yankfilter(0, x, ...))
end

local function peek(x, ...)
	local continuation, x = yield((select(x+1, ...)))
	return continuation(x, ...)
end

local function unpack(x, ...)
	local continuation, x = yield(...)
	return continuation(x, ...)
end

local function clear(x, ...)
	local continuation, x = yield()
	return continuation(x)
end

local function height(x, ...)
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
		push = function(x) resume(stack, push, x) end,
		pop = function()
			local _, x = resume(stack, pop)
			return x
		end,
		shove = function(i, x)
			shovei, shovex = i, x -- load shove registers
			resume(stack, shove, nil)
		end,
		yank = function(i)
			local _, x = resume(stack, yank, i)
			return x
		end,
		peek = function(i)
			local _, x = resume(stack, peek, i)
			return x
		end,
		unpack = function() return select(2, resume(stack, unpack)) end,
		clear = function() resume(stack, clear) end,
		height = function()
			local _, h = resume(stack, height)
			return h
		end,
	}
end

local function spush(x, ...)
	return x, ...
end

local function sdrop(tos, ...)
	return ...
end

local function sshove(i, x, ...)
	return shovefilter(0, i, x, ...)
end

local function syank(i, ...)
	return yankfilter(0, i, ...)
end

local function stop(tos, ...)
	return tos
end

local function sheight(...)
	return select("#", ...)
end

-- export
firth = firth or {}
firth.fstack = { new = new,
	spush = spush, sdrop = sdrop,
	sshove = sshove, syank = syank,
	stop = stop, sheight = sheight,
}
return firth.fstack