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

function prims.drop(compiler)
	compiler.stack:drop()
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

-- Compiles c = a OP b.
local function binop(compiler, op)
	local a = compiler:poptmp()
	local b = compiler:poptmp()
	local c = compiler:newtmp()
	compiler:append("%s = %s %s %s", c, a, op, b)
	compiler:pushtmp(c)
end

--! Compiles c = a + b.
--! @param compiler the Compiler object that called this function.
function prims.add(compiler)
	binop(compiler, '+')
end

--! Compiles c = a - b.
--! @param compiler the Compiler object that called this function.
function prims.sub(compiler)
	binop(compiler, '-')
end

--! Compiles c = a * b.
--! @param compiler the Compiler object that called this function.
function prims.mul(compiler)
	binop(compiler, '*')
end

--! Compiles c = a / b.
--! @param compiler the Compiler object that called this function.
function prims.div(compiler)
	binop(compiler, '/')
end

--! Compiles c = a % b.
--! @param compiler the Compiler object that called this function.
function prims.mod(compiler)
	binop(compiler, '%')
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

function prims.less(compiler)
	binop(compiler, "<")
end

function prims.greater(compiler)
	binop(compiler, ">")
end

function prims.equal(compiler)
	binop(compiler, "==")
end

function prims.lesseq(compiler)
	binop(compiler, "<=")
end

function prims.greatereq(compiler)
	binop(compiler, ">=")
end

function prims.noteq(compiler)
	binop(compiler, "~=")
end

-- os and io primitives --

function prims.dotprint(compiler)
	stringio.print(tostring(compiler.stack:pop()), ' ')
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

function prims.compilemode(compiler)
	local compiling = compiler.stack:pop()
	if (not compiler.compiling) and compiling then
		compiler:done()
	end
	compiler.compiling = compiling
end

function prims.compiling(compiler)
	compiler.stack:push(compiler.compiling)
end

--! Parses next token from input stream, and pushes it as a string.
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

function prims.enddef(compiler)
	compiler:done()
end

function prims.immediate(compiler)
	compiler:immediate()
end

function prims.char(compiler)
	local char = compiler:nexttoken()
	compiler:pushstring(char)
end

function prims.call(compiler)
	local word = compiler.stack:pop()
	compiler:call(word)
end

-- reflection, debugging, internal compiler state, etc. --

function prims.dump(compiler)
	compiler.stack:push(compiler.last.compilebuf)
end

function prims.dumpword(compiler)
	local word = compiler:nexttoken()
	local entry = compiler.dictionary[word]
	if not entry then
		compiler:error(word)
		return
	end
	compiler.stack:push(entry.compilebuf)
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
		drop = { func = prims.drop },

		['if'] = { func = prims.ifstmt, immediate = true },
		['else'] = { func = prims.elsestmt, immediate = true },
		['loop'] = { func = prims.loopstmt, immediate = true },
		['do'] = { func = prims.dostmt, immediate = true },
		['end'] = { func = prims.endstmt, immediate = true },

		['+'] = { func = prims.add, immediate = true },
		['-'] = { func = prims.sub, immediate = true },
		['*'] = { func = prims.mul, immediate = true },
		['/'] = { func = prims.div, immediate = true },
		['%'] = { func = prims.mod, immediate = true },

		['true'] = { func = prims.pushtrue, immediate = true },
		['false'] = { func = prims.pushfalse, immediate = true },
		['not'] = { func = prims.pushnot, immediate = true },
		['<'] = { func = prims.less, immediate = true },
		['>'] = { func = prims.greater, immediate = true },
		['='] = { func = prims.equal, immediate = true },
		['<='] = { func = prims.lesseq, immediate = true },
		['>='] = { func = prims.greatereq, immediate = true },
		['~='] = { func = prims.noteq, immediate = true },

		['.'] = { func = prims.dotprint },
		['..'] = { func = prims.dotprintstack },

		loadfile = { func = prims.loadfile },
		exit = { func = prims.exit, immediate = true },
		compilemode  = { func = prims.compilemode },
		['compiling?'] = { func = prims.compiling },
		parse = { func = prims.parse },
		push = { func = prims.push },
		define = { func = prims.define },
		[';'] = { func = prims.enddef, immediate = true },
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