--------------------------------------------------------------------------------
--! @file compiler-prims.lua
--! @brief Language primitives for Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015 Brigham Toskin
--! 
--! <p>This file is part of the Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--! @see compiler.lua
--------------------------------------------------------------------------------


--! @cond
local os = require "os"
local clock = os.clock
local string = require "string"

local stringio = require "firth.stringio"
local stack_new = (require "firth.stack").new

local exports = {}

local function buildentries(dict, map)
	for name, entry in pairs(dict) do
		local func = entry.func
		assert(type(func) == "function", "INIT ERROR: "..name)

		map[func] = name
		entry.name = name
		entry.calls = {}
		entry.calledby = {}
	end
end
--! @endcond

function exports.initialize(compiler)
	assert(type(compiler) == "table", "INVALID COMPILER REF")
	local dictionary, funcmap = compiler.dictionary, compiler.funcmap
	local stack, cstack = compiler.stack, compiler.cstack

	-- stack ops --

	local function dup()
		stack:dup()
	end

	local function over()
		stack:over()
	end

	local function drop()
		stack:drop()
	end

	local function clear()
		stack:clear()
	end

	local function swap()
		stack:swap()
	end

	local function rot()
		stack:rot()
	end

	local function revrot()
		stack:revrot()
	end

	local function pick()
		return stack:pick(stack:pop())
	end

	local function c_from()
		stack:push(cstack:pop())
	end

	local function to_c()
		cstack:push(stack:pop())
	end

	local function c_fetch()
		stack:push(cstack:top())
	end

	local function two_c_from()
		compiler:assert(cstack.height >= 2, "2C>", "CSTACK UNDERFLOW")
		local height = stack.height
		stack[height + 2], stack[height + 1] = cstack:pop(), cstack:pop()
		stack.height = height + 2
	end

	local function two_to_c()
		compiler:assert(stack.height >= 2, "2>C", "UNDERFLOW")
		local height = cstack.height
		cstack[height + 2], cstack[height + 1] = stack:pop(), stack:pop()
		cstack.height = height + 2
	end

	local function two_c_fetch()
		local height, cheight = stack.height, cstack.height
		compiler:assert(cheight >= 2, "2C@", "CSTACK UNDERFLOW")
		stack[height + 2], stack[height + 1] = cstack[cheight], cstack[cheight - 1]
		stack.height = height + 2
	end

	--! ( x s -- s ) ( s: -- x )
	local function to_s()
		local s = stack:pop()
		local val = stack:pop()
		s:push(val)
		stack:push(s)
	end

	--! ( s -- s x ) ( s: x -- )
	local function s_from()
		local s = stack:top()
		local val = s:pop()
		stack:push(val)
	end

	--! ( s -- s x ) ( s: x -- x )
	local function s_fetch()
		local s = stack:top()
		local val = s:top()
		stack:push(val)
	end

	--! ( x1 x2 s -- s ) ( s: -- x1 x2 )
	local function two_to_s()
		compiler:assert(stack.height >= 3, "2>[]", "UNDERFLOW")
		local s = stack:pop()
		compiler:assert(type(s) == "table" and s.height, "2>[]", "INVALID TARGET STACK")
		local height = s.height
		s[height + 2], s[height + 1] = stack:pop(), stack:pop()
		s.height = height + 2
		stack:push(s)
	end

	--! ( s -- s x1 x2 ) ( s: x1 x2 -- )
	local function two_s_from()
		local s = stack:top()
		compiler:assert(s.height >= 2, "2[]>", "UNDERFLOW")
		local height = stack.height
		stack[height + 2], stack[height + 1] = s:pop(), s:pop()
		stack.height = height + 2
	end

	--! ( s -- s x1 x2 ) ( s: x1 x2 -- x1 x2 )
	local function two_s_fetch()
		local s = stack:top()
		local height, sheight = stack.height, s.height
		compiler:assert(sheight >= 2, "2[]@", "UNDERFLOW")
		stack[height + 2], stack[height + 1] = s[sheight], s[sheight - 1]
		stack.height = height + 2
	end

	-- flow control --

	-- this is not meant to be a prim word available to firth code.
	-- is there a reasonable usecase for doing so?
	local function beginblock()
		local compiling = compiler.compiling
		if not compiling then compiler:create() end
		compiler.compiling = true
		cstack:push(compiling)
	end

	local function ifstmt()
		beginblock()
		local cond = compiler:poptmp()
		compiler:append("if %s then", cond)
	end

	local function elsestmt()
		compiler:append("else")
	end

	local function loopsstmt()
		beginblock()
		local count = compiler:poptmp()
		compiler:append("for _ = 1, %s do", count)
	end

	local function dostmt()
		beginblock()
		compiler:append("do")
	end

	local function endstmt()
		compiler:append("end")
		local compiling = cstack:pop()
		compiler.compiling = compiling
		if not compiling then
			compiler:create()
		end
	end

	-- inline operations --

	--! ( operator -- )
	local function binop()
		local op = stack:pop()

		local roperand = compiler:poptmp()
		local loperand = compiler:toptmp()
		local lval = compiler:newtmp(string.format("%s %s %s", loperand, op, roperand))
		compiler:append("rawset(stack, stack.height, %s)", lval)
	end

	local function binopconst()
		local op = stack:pop()
		local cval = stack:pop()

		local val = compiler:toptmp()
		local newval = compiler:newtmp(string.format("%s %s %s", val, op, cval))
		compiler:append("rawset(stack, stack.height, %s)", newval)
	end

	-- boolean stuff --

	local function pushtrue()
		compiler:push(true)
	end

	local function pushfalse()
		compiler:push(false)
	end

	local function pushnot()
		if compiler.compiling then
			compiler:append("stack[stack.height] = not stack:top()")
		else
			stack[stack.height] = not stack:top()
		end
	end

	local function push2not()
		local height = compiler:newtmp("stack.height")
		compiler:cassert(height.." > 1", "UNDERFLOW")
		local prev = compiler:newtmp(height.." - 1")
		compiler:append("stack[%s], stack[%s] = not stack[%s], not stack[%s]",
			height, prev, height, prev)
	end

	local function pushnil()
		compiler:push(nil)
	end

	local function pushtable()
		compiler:push({})
	end

	local function pushstack()
		compiler:push(stack_new())
	end

	local function pushtype()
		local typ
		if compiler.compiling then
			local val = compiler:poptmp()
			typ = compiler:newtmpfmt("type(%s)", val)
		else
			typ = type(stack:pop())
		end
		compiler:push(typ)
	end

	-- bitwise boolean ops --

	-- only available in LuaJIT 2.0+ or Lua 5.2+
	local bit = bit or bit32
	local band, bor, bxor, bnot
	if bit then
		local bitand, bitor, bitxor, bitnot = bit.band, bit.bor, bit.bxor, bit.bnot

		function band()
			stack:push(bitand(stack:pop(), stack:pop()))
		end

		function bor()
			stack:push(bitor(stack:pop(), stack:pop()))
		end

		function bxor()
			stack:push(bitxor(stack:pop(), stack:pop()))
		end

		function bnot()
			stack:push(bitnot(stack:pop()))
		end
	end

	-- os and io primitives --

	local function rawprint()
		local tos = stack:pop()
		compiler:assert(type(tos) == "string", ".raw", "NOT A STRING")
		stringio.print(tos)
	end

	local function dotprint()
		-- have to actually pop, to avoid cycles
		stack:push(tostring(stack:pop())..' ')
		rawprint()
	end

	local function dotprinthex()
		local tos = stack:top()
		stack[stack.height] = string.format("0x%X", tonumber(tos))
		dotprint()
	end

	local function dotprints()
		-- stringio.print(tostring(stack), ' ')
		stack:push(stack)
		dotprint()
	end

	local function dotprintc()
		-- stringio.print(tostring(cstack), ' ')
		stack:push(cstack)
		dotprint()
	end

	-- parser/compiler control words --

	local function loadfile()
		compiler:loadfile(stack:pop())
	end

	local function exit()
		compiler.running = false
	end

	--! ( -- )
	local function setcompiling()
		compiler.compiling = true
	end

	--! ( name -- entry )
	local function create()
		compiler:create(stack:pop())
	end

	--! ( entry -- )
	local function alias()
		local entry = stack:pop()
		local newname = compiler:nexttoken()
		dictionary[newname] = entry
	end

	--! ( entry -- C: oldentry? )
	local function settarget()
		compiler:settarget(stack:pop())
	end

	local function interpret()
		if compiler.compiling then
			compiler.compiling = false
		end
	end

	--! ( -- bool )
	local function compiling()
		stack:push(compiler.compiling)
	end

	--! ( c -- word ) Parses next token from input stream, and pushes it as a string.
	local function parse()
		local delim = stack:pop()
		local success, token = pcall(compiler.nexttoken, compiler, delim)
		compiler:assert(success, "parse", "UNABLE TO RETRIEVE TOKEN")
		stack:push(token)
	end

	--! ( pattern -- tok )
	local function parsematch()
		local pattern = stack:pop()
		local success, token, src = pcall(stringio.matchtoken, compiler.src, pattern)
		compiler:assert(success, "parsematch", "UNABLE TO RETRIEVE TOKEN")
		stack:push(token)
		compiler.src = src
	end

	--! ( str -- )
	local function ungettoken()
		compiler.src = tostring(stack:pop())..' '..compiler.src
	end

	--! ( C: entry -- C: entry' )
	local function push()
		if not compiler.compiling then return end

		local val = stack:pop()

		-- compiler:push() can't tell if its arg is a literal string from a
		-- firth word, or meant to be a compiled expression from a codegen
		-- function. so, we need to determine that here and choose the right
		-- version of push.
		if type(val) == "string" then
			compiler:pushstring(val)
		else
			compiler:push(val)
		end
	end

	--! ( C: entry -- C: entry' )
	local function buildfunc()
		compiler:buildfunc()
	end

	--! ( C: entry -- )
	local function bindfunc()
		compiler:bindfunc()
	end

	--! ( entry -- )
	local function does()
		local varentry = compiler:poptmp()
		local doesname = compiler:newtmpstr(compiler:nexttoken())
		local doesentry = compiler:newtmpfmt("compiler:lookup(%s)", doesname)
		local doesfunc = compiler:newtmpfmt("%s.func", doesentry)
		local closure = [[
			varentry.func = function()
				stack:push(varentry)
				doesfunc()
			end]]
		closure = closure:gsub("varentry", varentry):gsub("doesfunc", doesfunc)
		compiler:append(closure)
		compiler:append("cstack:push(%s)", varentry)
		compiler:append("compiler:bindfunc()")
		compiler:append("%s.compilebuf = {%q}", varentry, closure)
	end

	--! ( name -- entry )
	local function dict()
		local word = stack:pop()
		local entry = compiler:lookup(word)
		stack:push(entry)
	end

	--! ( -- entry )
	local function last()
		stack:push(compiler.last)
	end

	--! ( -- b ) TS: word
	local function defined()
		local name = compiler:nexttoken()
		compiler:push(dictionary[name] ~= nil)
	end

	--! @@ ( t k -- x )
	local function fetchfield()
		local idx = stack:pop()
		local tab = stack:pop()
		stack:push(tab[idx])
	end

	--! !! ( x t k -- )
	local function storefield()
		local idx = stack:pop()
		local tab = stack:pop()
		local val = stack:pop()
		tab[idx] = val
	end

	--! ( -- )
	local function immediate()
		compiler:immediate()
	end

	--! ( -- c )
	local function char()
		local str = compiler:nexttoken()
		local char = str:sub(1, 1)
		if char == "%" or char == "\\" then char = str:sub(1, 2) end
		compiler:pushstring(char)
	end

	--! ( name -- )
	local function call()
		local name = stack:pop()
		if compiler.compiling then
			compiler:call(name)
		else
			local entry = compiler:lookup(name)
			entry.func()
		end
	end

	--! ( xt -- i*x )
	local function execute()
		local xt = stack:pop()
		xt()
	end

	-- reflection, debugging, internal compiler state, etc. --

	local function dumpword()
		local word = compiler:nexttoken()
		local entry = compiler:lookup(word)
		stack:push(table.concat(entry.compilebuf, '\n'))
	end

	local function dump()
		stack:push(table.concat(compiler.last.compilebuf, '\n'))
	end

	local function trace()
		compiler.tracing = true
	end

	local function notrace()
		compiler.tracing = false
	end

	local function tracing()
		stack:push(compiler.tracing)
	end

	local function path()
		stack:push(compiler.path)
	end

	local function calls()
		local word = compiler:nexttoken()
		for caller, _ in pairs(dictionary[word].calledby) do
			stringio.printline(string.format("\tcalled by %s", caller))
		end
	end

	local function calledby()
		local word = compiler:nexttoken()
		for callee, _ in pairs(dictionary[word].calls) do
			stringio.printline(string.format("\tcalls %s", callee))
		end
	end

	local function tstart()
		stack:push(clock())
	end

	local function tend()
		local fin = clock()
		local diff = fin - stack:pop()
		stringio.printline('(', diff, " seconds)")
	end

	-- load up the dictionary --

	dictionary.dup = { func = dup }
	dictionary.over = { func = over }
	dictionary.drop = { func = drop }
	dictionary.clear = { func = clear }
	dictionary.swap = { func = swap }
	dictionary.rot = { func = rot }
	dictionary['-rot'] = { func = revrot }
	dictionary.pick = { func = pick }
	dictionary['C>'] = { func = c_from }
	dictionary['>C'] = { func = to_c }
	dictionary['C@'] = { func = c_fetch }
	dictionary['2C>'] = { func = two_c_from }
	dictionary['2>C'] = { func = two_to_c }
	dictionary['2C@'] = { func = two_c_fetch }
	dictionary['>[]'] = { func = to_s }
	dictionary['[]>'] = { func = s_from }
	dictionary['[]@'] = { func = s_fetch }
	dictionary['2>[]'] = { func = two_to_s }
	dictionary['[2]>'] = { func = two_s_from }
	dictionary['[2]@'] = { func = two_s_fetch }

	dictionary['if'] = { func = ifstmt, immediate = true }
	dictionary['else'] = { func = elsestmt, immediate = true }
	dictionary['loops'] = { func = loopsstmt, immediate = true }
	dictionary['do'] = { func = dostmt, immediate = true }
	dictionary['end'] = { func = endstmt, immediate = true }

	dictionary.binop = { func = binop }
	dictionary.binopconst = { func = binopconst }

	dictionary['true'] = { func = pushtrue, immediate = true }
	dictionary['false'] = { func = pushfalse, immediate = true }
	dictionary['not'] = { func = pushnot, immediate = true }
	dictionary['2not'] = { func = push2not, immediate = true }
	dictionary['nil'] = { func = pushnil, immediate = true }
	dictionary['{}'] = { func = pushtable, immediate = true }
	dictionary['[]'] = { func = pushstack, immediate = true }
	dictionary['type'] = { func = pushtype, immediate = true }

	dictionary['.raw'] = { func = rawprint }
	dictionary['.'] = { func = dotprint }
	dictionary['.x'] = { func = dotprinthex }
	dictionary['.S'] = { func = dotprints }
	dictionary['.C'] =  { func = dotprintc }

	dictionary.loadfile = { func = loadfile }
	dictionary.exit = { func = exit, immediate = true }
	dictionary.setcompiling  = { func = setcompiling }
	dictionary.settarget  = { func = settarget }
	dictionary.interpret = { func = interpret, immediate = true }
	dictionary['compiling?'] = { func = compiling }
	dictionary.parse = { func = parse }
	dictionary.parsematch = { func = parsematch }
	dictionary['>ts'] = { func = ungettoken }
	dictionary.push = { func = push }
	dictionary.create = { func = create }
	dictionary['alias:'] = { func = alias, immediate = true }
	dictionary.buildfunc = { func = buildfunc }
	dictionary.bindfunc = { func = bindfunc }
	dictionary['does>'] = { func = does, immediate = true }
	dictionary.dict = { func = dict }
	dictionary.last = { func = last }
	dictionary["defined?"] = { func = defined, immediate = true }
	dictionary['@@'] = { func = fetchfield }
	dictionary['!!'] = { func = storefield }
	dictionary.immediate = { func = immediate }
	dictionary.char = { func = char, immediate = true }
	dictionary.call = { func = call }
	dictionary.execute = { func = execute }

	dictionary.dump = { func = dump }
	dictionary['dumpword:'] = { func = dumpword, immediate = true }
	dictionary.trace = { func = trace }
	dictionary.notrace = { func = notrace }
	dictionary['tracing?'] = { func = tracing }
	dictionary.path = { func = path }
	dictionary['calls:'] = { func = calls, immediate = true }
	dictionary['calledby:'] = { func = calledby, immediate = true }
	dictionary.tstart = { func = tstart }
	dictionary.tend = { func = tend }

	if bit then
		dictionary["&"] = { func = band }
		dictionary["|"] = { func = bor }
		dictionary["^"] = { func = bxor }
		dictionary["~"] = { func = bnot }
	end

	dictionary.NOP = { func = compiler.NOP }

	buildentries(dictionary, funcmap)
end


return exports
