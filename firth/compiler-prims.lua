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
local string = require 'string'
local stringio = require 'firth.stringio'

local prims = {}
--! @endcond


-- stack ops --

function prims.dup(compiler)
	compiler.stack:dup()
end

function prims.over(compiler)
	compiler.stack:over()
end

function prims.drop(compiler)
	compiler.stack:drop()
end

function prims.swap(compiler)
	compiler.stack:swap()
end

function prims.rot(compiler)
	compiler.stack:rot()
end

function prims.revrot(compiler)
	compiler.stack:revrot()
end

function prims.pick(compiler)
	return compiler.stack:pick(compiler.stack:pop())
end

-- flow control --

function prims.ifstmt(compiler)
	local cond = compiler:poptmp()
	compiler:append("if %s then", cond)
end

function prims.elsestmt(compiler)
	compiler:append("else")
end

function prims.loopstmt(compiler)
	local count = compiler:poptmp()
	compiler:append("for _ = 1, %s do", count)
end

function prims.dostmt(compiler)
	compiler:append("do")
end

function prims.endstmt(compiler)
	compiler:append("end")
end

-- inline operations --

--! ( operator -- )
function prims.binop(compiler)
	local op = compiler.stack:pop()

	local roperand = compiler:poptmp()
	local loperand = compiler:poptmp()
	local lval = compiler:newtmp()
	compiler:append("%s = %s %s %s", lval, loperand, op, roperand)
	compiler:pushtmp(lval)
end

-- boolean stuff --

function prims.pushtrue(compiler)
	compiler:push(true)
end

function prims.pushfalse(compiler)
	compiler:push(false)
end

function prims.pushnot(compiler)
	local stack = compiler:newtmp("compiler.stack")
	compiler:append("%s[#%s] = not %s[#%s]", stack, stack, stack, stack)
end

-- bitwise boolean ops --

-- only available in LuaJIT 2.0+ or Lua 5.2+
local bitops = bit or bit32
if bitops then
	function prims.band(compiler)
		local stack = compiler.stack
		stack:push(bitops.band(stack:pop(), stack:pop()))
	end

	function prims.bor(compiler)
		local stack = compiler.stack
		stack:push(bitops.bor(stack:pop(), stack:pop()))
	end

	function prims.bxor(compiler)
		local stack = compiler.stack
		stack:push(bitops.bxor(stack:pop(), stack:pop()))
	end

	function prims.bnot(compiler)
		local stack = compiler.stack
		stack:push(bitops.bnot(stack:pop()))
	end
end

-- os and io primitives --

function prims.dotprint(compiler)
	local tos = compiler.stack:pop()
	stringio.print(tostring(tos), ' ')
end

function prims.dotprintstack(compiler)
	stringio.printstack(compiler.stack)
end

-- parser/compiler control words --

function prims.loadfile(compiler)
	compiler:loadfile(compiler.stack:pop())
end

function prims.exit(compiler)
	compiler.running = false
end

function prims.compile(compiler)
	if not compiler.compiling then
		compiler:interpretpending()
	end
	compiler.compiling = true
end

function prims.interpret(compiler)
	compiler.compiling = false
end

function prims.compiling(compiler)
	compiler.stack:push(compiler.compiling)
end

--! ( c -- word ) Parses next token from input stream, and pushes it as a string.
function prims.parse(compiler)
	local delim = compiler.stack:pop()
	local token = compiler:nexttoken(delim)
	compiler.stack:push(token)
end

function prims.push(compiler)
	local val = compiler.stack:pop()
	if type(val) == "string" then
		compiler:pushstring(val)
	else
		compiler:push(val)
	end
end

function prims.define(compiler)
	compiler:newentry(compiler.stack:pop())
end

--! ( -- name, buf )
function prims.compilebuf(compiler)
	local name, buf = compiler:currentbuf()
	compiler.stack:push(name)
	compiler.stack:push(buf)
end

--! ( name, buf -- name, func )
function prims.buildfunc(compiler)
	local buf = compiler.stack:pop()
	local _, func = compiler:buildfunc(compiler.stack:top(), buf)
	compiler.stack:push(func)
end

--! ( name, func -- )
function prims.bindfunc(compiler)
	local func = compiler.stack:pop()
	local name = compiler.stack:pop()
	compiler:bindfunc(name, func)
end

function prims.immediate(compiler)
	compiler:immediate()
end

function prims.char(compiler)
	local str = compiler:nexttoken()
	local char = str:sub(1, 1)
	if char == "%" or char == "\\" then char = str:sub(1, 2) end
	compiler:pushstring(char)
end

function prims.call(compiler)
	local word = compiler.stack:pop()
	compiler:call(word)
end

-- reflection, debugging, internal compiler state, etc. --

function prims.dump(compiler)
	compiler.stack:push(table.concat(compiler.last.compilebuf, '\n'))
end

function prims.dumpword(compiler)
	local word = compiler:nexttoken()
	local entry = compiler.dictionary[word]
	if not entry then
		compiler:lookuperror(word)
		return
	end
	compiler.stack:push(table.concat(entry.compilebuf, '\n'))
end

function prims.trace(compiler)
	compiler.trace = true
end

function prims.notrace(compiler)
	compiler.trace = false
end

function prims.tracing(compiler)
	compiler.stack:push(compiler.trace)
end

function prims.calls(compiler)
	local word = compiler:nexttoken()
	for callee, _ in pairs(compiler.dictionary[word].calledby) do
		stringio.printline(string.format("\tCalled by %s", callee))
	end
end

function prims.calledby(compiler)
	local word = compiler:nexttoken()
	for callee, _ in pairs(compiler.dictionary[word].calls) do
		stringio.printline(string.format("\tCalls %s", callee))
	end
end

-- export to dictionary --

local function buildentries(dict)
	if bitops then
		dict["&"] = { func = prims.band }
		dict["|"] = { func = prims.bor }
		dict["^"] = { func = prims.bxor }
		dict["~"] = { func = prims.bnot }
	end
	for name, entry in pairs(dict) do
		entry.name = name
		entry.calls = {}
		entry.calledby = {}
		assert(type(entry.func) == "function", name.." improperly initialized")
	end
	return dict
end

function prims.initialize()
	return buildentries{
		dup = { func = prims.dup },
		over = { func = prims.over },
		drop = { func = prims.drop },
		swap = { func = prims.swap },
		rot = { func = prims.rot },
		['-rot'] = { func = prims.revrot },
		pick = { func = prims.pick },

		['if'] = { func = prims.ifstmt, immediate = true },
		['else'] = { func = prims.elsestmt, immediate = true },
		['loop'] = { func = prims.loopstmt, immediate = true },
		['do'] = { func = prims.dostmt, immediate = true },
		['end'] = { func = prims.endstmt, immediate = true },

		binop = { func = prims.binop },

		['true'] = { func = prims.pushtrue, immediate = true },
		['false'] = { func = prims.pushfalse, immediate = true },
		['not'] = { func = prims.pushnot, immediate = true },

		['.'] = { func = prims.dotprint },
		['..'] = { func = prims.dotprintstack },

		loadfile = { func = prims.loadfile },
		exit = { func = prims.exit, immediate = true },
		compile  = { func = prims.compile },
		interpret = { func = prims.interpret, immediate = true },
		['compiling?'] = { func = prims.compiling },
		parse = { func = prims.parse },
		push = { func = prims.push },
		define = { func = prims.define },
		compilebuf = { func = prims.compilebuf },
		buildfunc = { func = prims.buildfunc },
		bindfunc = { func = prims.bindfunc },
		immediate = { func = prims.immediate },
		char = { func = prims.char, immediate = true },
		call = { func = prims.call },

		dump = { func = prims.dump },
		['dumpword:'] = { func = prims.dumpword, immediate = true },
		trace = { func = prims.trace },
		notrace = { func = prims.notrace },
		['trace?'] = { func = prims.tracing },
		['calls:'] = { func = prims.calls, immediate = true },
		['calledby:'] = { func = prims.calledby, immediate = true },
	}
end


return prims