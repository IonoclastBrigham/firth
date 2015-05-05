local create, yield, resume = coroutine.create, coroutine.yield, coroutine.resume

local function yank(n, i, ...)
	if select("#", ...) == 0 then return end
	if i == n then return select(2, ...) end
	return (...), yank(n+1, i, select(2, ...))
end

local function stack(cmd, x, ...)	
--	print("STACK:", ...)
--	print("CMD:", cmd, "ARG:", x)

	-- process stack commands
	if cmd == "PUSH" then
		local cmd, nx = yield()
		return stack(cmd, nx, x, ...)
	elseif cmd == "POP" then
		cmd, x = yield((...))
		return stack(cmd, x, select(2, ...))
	elseif cmd == "YANK" then
		local cmd, nx = yield((select(x+1, ...)))
		return stack(cmd, nx, yank(0, x, ...))
	elseif cmd == "PEEK" then
		cmd, x = yield((select(x+1, ...)))
		return stack(cmd, x, ...)
	elseif cmd == "UNPACK" then
		cmd, x = yield(...)
		return stack(cmd, x, ...)
	elseif cmd == "CLEAR" then
		cmd, x = yield(...)
		return stack(cmd, x)
	elseif cmd == "HEIGHT" then
		cmd, x = yield(select("#", ...))
		return stack(cmd, x, ...)
	end

	-- fallback; pre-load stack and wait for first command
	cmd, x = yield()
	return stack(cmd, x, ...)
end

local function new(...)
	local co = create(stack)
	resume(co, nil, nil, ...)
	return {
		push = function(x) resume(co, "PUSH", x) end,
		pop = function() return select(2, resume(co, "POP")) end,
		yank = function(i) return select(2, resume(co, "YANK", i)) end,
		peek = function(i) return select(2, resume(co, "PEEK", i)) end,
		unpack = function() return select(2, resume(co, "UNPACK")) end,
		clear = function() return select(2, resume(co, "CLEAR")) end,
		height = function() return select(2, resume(co, "HEIGHT")) end,
	}
end

-- export
firth = firth or {}
firth.fstack = { new = new }
return firth.fstack