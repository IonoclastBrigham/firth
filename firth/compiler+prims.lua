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
local string = require "string"
local stringio = require "firth.stringio"

local clock = os.clock

local exports = {}

local function buildentries(dict)
	for name, entry in pairs(dict) do
		entry.name = name
		entry.calls = {}
		entry.calledby = {}
		assert(type(entry.func) == "function", name.." improperly initialized")
	end
end
--! @endcond

function exports.initialize(compiler)
	assert(compiler, "INVALID COMPILER REF")
	local dictionary, stack, cstack = compiler.dictionary, compiler.stack, compiler.cstack

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

	-- flow control --

	local function ifstmt()
		local cond = compiler:poptmp()
		compiler:append("if %s then", cond)
	end

	local function elsestmt()
		compiler:append("else")
	end

	local function loopsstmt()
		local count = compiler:poptmp()
		compiler:append("for _ = 1, %s do", count)
	end

	local function dostmt()
		compiler:append("do")
	end

	local function endstmt()
		compiler:append("end")
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

	-- boolean stuff --

	local function pushtrue()
		compiler:push(true)
	end

	local function pushfalse()
		compiler:push(false)
	end

	local function pushnot()
		local height = compiler:newtmp("stack.height")
		compiler:append("stack[%s] = not stack[%s]", height, height)
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
		if type(tos) ~= "string" then compiler:runtimeerror(".raw", "NOT A STRING") end
		stringio.print(tos)
	end

	local function dotprint()
		stack[stack.height] = tostring(stack:top())..' '
		rawprint()
	end

	local function dotprintstack()
		stringio.stacktrace(stack)
	end

	local function dotprinthex()
		local tos = stack:pop()
		stringio.print(string.format("0x%X", tonumber(tos)), ' ')
	end

	-- parser/compiler control words --

	local function loadfile()
		compiler:loadfile(stack:pop())
	end

	local function exit()
		compiler.running = false
	end

	--! ( entry -- C: entry )
	local function interpretpending()
--		print("EXEC WORD interpretpending")
		compiler:interpretpending()
	end

	--! ( -- )
	local function setcompiling()
		compiler.compiling = true
	end

	--! ( name -- entry )
	local function newentry()
		compiler:newentry(stack:pop(), true)
	end

	--! ( entry -- C: oldentry? )
	local function settarget()
		compiler:settarget(stack:pop())
	end

	local function interpret()
--		stringio.printstack(cstack)
		if compiler.compiling then
			compiler.compiling = false

			local target = compiler.target
			compiler:restoretarget()
			cstack:push(target)
			if not compiler.target then
				compiler:newentry()
			end
		end
--		stringio.printstack(cstack)
	end

	--! ( -- bool )
	local function compiling()
		stack:push(compiler.compiling)
	end

	--! ( c -- word ) Parses next token from input stream, and pushes it as a string.
	local function parse()
		local delim = stack:pop()
		local success, token = pcall(compiler.nexttoken, compiler, delim)
		if not success then compiler:runtimeerror("parse", "UNABLE TO RETRIEVE TOKEN") end
		stack:push(token)
	end

	--! ( pattern -- tok )
	local function parsematch()
		local pattern = stack:pop()
		local success, token, line = pcall(stringio.matchtoken, compiler.line, pattern)
		if not success then compiler:runtimeerror("parsematch", "UNABLE TO RETRIEVE TOKEN") end
		stack:push(token)
		compiler.line = line
	end

	--! ( str -- )
	local function ungettoken()
		compiler.line = tostring(stack:pop())..compiler.line
	end

	--! ( C: entry -- C: entry' )
	local function push()
		local val = stack:pop()
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

	--! ( name -- entry )
	local function dict()
		local word = stack:pop()
		local entry = dictionary[word]
		if not entry then compiler:lookuperror(word) end
		stack:push(entry)
	end


	local function immediate()
		compiler:immediate()
	end

	--! ( C: entry -- C: entry' )
	local function char()
		local str = compiler:nexttoken()
		local char = str:sub(1, 1)
		if char == "%" or char == "\\" then char = str:sub(1, 2) end
		compiler:pushstring(char)
	end

	--! ( C: entry -- C: entry' )
	local function call()
		compiler:call(stack:pop())
	end

	-- reflection, debugging, internal compiler state, etc. --

--	local function dumpword()
--		local word = compiler:nexttoken()
--		local entry = dictionary[word]
--		if not entry then compiler:lookuperror(word) end
--		stack:push(table.concat(entry.compilebuf, '\n'))
--	end
--
--	local function dump()
--		stack:push(table.concat(compiler.last.compilebuf, '\n'))
--	end

	local function trace()
		compiler.trace = true
	end

	local function notrace()
		compiler.trace = false
	end

	local function tracing()
		stack:push(compiler.trace)
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

	dictionary.dup = { func = dup }
	dictionary.over = { func = over }
	dictionary.drop = { func = drop }
	dictionary.swap = { func = swap }
	dictionary.rot = { func = rot }
	dictionary['-rot'] = { func = revrot }
	dictionary.pick = { func = pick }

	dictionary['if'] = { func = ifstmt, immediate = true }
	dictionary['else'] = { func = elsestmt, immediate = true }
	dictionary['loops'] = { func = loopsstmt, immediate = true }
	dictionary['do'] = { func = dostmt, immediate = true }
	dictionary['end'] = { func = endstmt, immediate = true }

	dictionary.binop = { func = binop }

	dictionary['true'] = { func = pushtrue, immediate = true }
	dictionary['false'] = { func = pushfalse, immediate = true }
	dictionary['not'] = { func = pushnot, immediate = true }

	dictionary['.raw'] = { func = rawprint }
	dictionary['.'] = { func = dotprint }
	dictionary['.x'] = { func = dotprinthex }
	dictionary['..'] = { func = dotprintstack }

	dictionary.loadfile = { func = loadfile }
	dictionary.exit = { func = exit, immediate = true }
	dictionary.setcompiling  = { func = setcompiling }
	dictionary.settarget  = { func = settarget }
	dictionary.interpretpending = { func = interpretpending }
	dictionary.interpret = { func = interpret, immediate = true }
	dictionary['compiling?'] = { func = compiling }
	dictionary.parse = { func = parse }
	dictionary.parsematch = { func = parsematch }
	dictionary['>ts'] = { func = ungettoken }
	dictionary.push = { func = push }
	dictionary.newentry = { func = newentry }
	dictionary.buildfunc = { func = buildfunc }
	dictionary.bindfunc = { func = bindfunc }
	dictionary.dict = { func = dict }
	dictionary.immediate = { func = immediate }
	dictionary.char = { func = char, immediate = true }
	dictionary.call = { func = call }

--	dictionary.dump = { func = dump }
--	dictionary['dumpword:'] = { func = dumpword, immediate = true }
	dictionary.trace = { func = trace }
	dictionary.notrace = { func = notrace }
	dictionary['trace?'] = { func = tracing }
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

	buildentries(dictionary)
end


return exports