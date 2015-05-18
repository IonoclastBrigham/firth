-- lua test harness to test 6 different threading models:
--	nested calls
--	more traditional threading
--	threading with closures instead of conditionals
--	closures with continuations
--	closures with continuations, operators inlined
--	treaded stack
-- and then, for reference:
--	current firth implementation, using inline operators
--	current firth implementation, using math calls
--	native lua equivalent
-- We will be simulating the word:
--	: foo ( n1 n2 n3 n4 n5 -- n6 ) + - * / ; 


local time = os.clock

local unpack = unpack or table.unpack

local stack = require "firth.fstack"
local push, drop, top = stack.push, stack.drop, stack.top
local shove, yank, chop, peek = stack.shove, stack.yank, stack.chop, stack.peek
local height = stack.height

local function dup(tos, ...) return tos, tos, ... end

-- local firth = require "firth.compiler"
	

-- words to call --

local function add(b, a, ...)
	return push(a + b, ...)
end

local function sub(b, a, ...)
	return push(a - b, ...)
end

local function mul(b, a, ...)
	return push(a * b, ...)
end

local function div(b, a, ...)
	return push(a / b, ...)
end

local foothread = {add, sub, mul, div}

-- threading mathinery --

-- nested function calls
local function nested(...)
	return div(mul(sub(add(...))))
end

-- more traditional threaded execution
local execute
local function execthread(n, th, ...)
	local xt = th[n]
	if not xt then return ... end
	return execthread(n+1, th, execute(xt, ...))
end
execute = function(xt, ...)
	if type(xt) == "function" then return xt(...) end
	return execthread(1, xt, ...)
end
local function threaded(...)
	return execute(foothread, ...)
end

-- threaded with closures instead of conditionals
local threadstable = {}
local function execthread(n, th, ...)
	-- this version assumes all xts in thread are functions
	local xt = th[n]
	if not xt then return ... end
	return execthread(n+1, th, xt(...))
end
local function closethread(th)
	local closure = threadstable[th]
	if not closure then
		closure =	function(...)
						return execthread(1, th, ...)
					end
		threadstable[th] = closure
	end
	return closure
end
local threadedclosures = closethread(foothread)

-- closures with continuations
local function thread(fa, fb, ...)
	if not fb then return fa end
	local next = thread(fb, ...)
	return function(...) return next(fa(...)) end
end
local continuations = thread(unpack(foothread))

-- closures, continuations, inlined operators
local function thread(fa, fb, ...)
	-- this version tries to inline known operators
	if not fb then return fa end
	local next = thread(fb, ...)
	if fa == add then
		return  function(n2, n1, ...)
			return next(n1+n2, ...)
		end
	elseif fa == sub then
		return function(n2, n1, ...)
			return next(n1-n2, ...)
		end
	elseif fa == mul then
		return function(n2, n1, ...)
			return next(n1*n2, ...)
		end
	else
		return function(...) return next(fa(...)) end
	end
end
local contsinline = thread(unpack(foothread))
	
-- thread lives on the stack
local function splicewithcall(n, len, xt, ...)
	if n == len then return xt(...) end
	return ..., splicewithcall(n+1, len, xt, drop(...))
end
local function execthread(len, xt, ...)
	-- this version pops xts off the stack
	if len == 1 then return xt(...) end
	return execthread(len-1, splicewithcall(1, len, xt, ...))
end
local function stackthread(...)
	return execthread(4, add, sub, mul, div, ...)
end

-- -- current firth, inline operators
-- local fooword = ": foo   + - * / ;"
-- local c = firth.new()
-- local s = c.stack
-- local d = c.dictionary
-- c:interpret(fooword)
-- local fooxt = d.foo.func
-- local function inlinefirth(...)
-- 	s:pushv(...)
-- 	fooxt()
-- 	return s:pop()
-- end

-- -- current firth, "operator" words
-- local opwords = [[
-- 	: add   + ;
-- 	: sub   - ;
-- 	: mul   * ;
-- 	: div   / ;
-- 	: foo2   add sub mul div ;]]
-- c:interpret(opwords)
-- local foo2xt = d.foo2.func
-- local function routinesfirth(...)
-- 	s:pushv(...)
-- 	foo2xt()
-- 	return s:pop()
-- end


-- native lua implementation
local function native(n5, n4, n3, n2, n1)
	return (n1 / (n2 * (n3 - (n4 + n5))))
end

-- test harness --

local function timer(f, ...)
	io.write("."); io.flush()
	local t0 = time()
	for i=1,1000000 do f(...) end
	return time() - t0
end

local function printresults(t)
	table.sort(t, function(a, b) return a[2] < b[2] end)
	print()
	for _,v in ipairs(t) do print(("%s\t%.4f seconds"):format(v[1], v[2])) end
end

local function runtests(...)
	-- print(continuations(...))
	local results, insert = {}, 1
	results[insert] = { "Nested:\t", timer(nested, ...) }
	insert = insert + 1
	results[insert] = { "Threaded:", timer(threaded, ...) }
	insert = insert + 1
	results[insert] = { "Closures:", timer(threadedclosures, ...) }
	insert = insert + 1
	results[insert] = { "Continuations:", timer(continuations, ...) }
	insert = insert + 1
	results[insert] = { "Contins inline:", timer(contsinline, ...) }
	insert = insert + 1
	results[insert] = { "Stack:\t", timer(stackthread, ...) }
	insert = insert + 1
	-- results[insert] = { "Inline Firth:", timer(inlinefirth, ...) }
	-- insert = insert + 1
	-- results[insert] = { "Routines Firth:", timer(routinesfirth, ...) }
	-- insert = insert + 1
	results[insert] = { "Native:\t", timer(native, ...) }
	printresults(results)
end

runtests(5, 4, 3, 2, 1)
