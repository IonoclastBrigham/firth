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
	if compiler.compiling then
		binop(compiler, '+')
	else
		compiler.stack:push(compiler.stack:pop() + compiler.stack:pop())
	end
end

--! Compiles c = a - b.
--! @param compiler the Compiler object that called this function.
function prims.sub(compiler)
	if compiler.compiling then
		binop(compiler, '-')
	else
		compiler.stack:push(compiler.stack:pop() - compiler.stack:pop())
	end
end

--! Compiles c = a * b.
--! @param compiler the Compiler object that called this function.
function prims.mul(compiler)
	if compiler.compiling then
		binop(compiler, '*')
	else
		compiler.stack:push(compiler.stack:pop() * compiler.stack:pop())
	end
end

--! Compiles c = a / b.
--! @param compiler the Compiler object that called this function.
function prims.div(compiler)
	if compiler.compiling then
		binop(compiler, '/')
	else
		compiler.stack:push(compiler.stack:pop() / compiler.stack:pop())
	end
end

--! Compiles c = a % b.
--! @param compiler the Compiler object that called this function.
function prims.plus(compiler)
	if compiler.compiling then
		binop(compiler, '%')
	else
		compiler.stack:push(compiler.stack:pop() % compiler.stack:pop())
	end
end

-- os and io primitives --

function prims.dotprint(compiler)
	stringio.print(compiler.stack:pop()..' ')
end

-- parser/compiler control words --

function prims.exit(compiler)
	compiler.running = false
end

function prims.defer(compiler)
	-- TODO
end

-- opposite of defer
function prims.eval(compiler)
	-- TODO
end

--! Parses next token from input stream, and pushes it as a string.
function prims.parse(compiler)
	local delim = compiler.stack:pop()
	local token = compiler:nexttoken(delim)
	compiler.stack:push(token)
end

function prims.define(compiler)
	local word = compiler:nexttoken()
	compiler:newfunc(word)
end

function prims.enddef(compiler)
	compiler:done()
end

function prims.immediate(compiler)
	-- TODO
end

function prims.char(compiler)
	local char = compiler:nexttoken()
	compiler.stack:push(char)
end

-- export to dictionary --

function prims.initialize()
	return {
		['+'] = { func = prims.add, immediate = true },
		['-'] = { func = prims.sub, immediate = true },
		['*'] = { func = prims.mul, immediate = true },
		['/'] = { func = prims.div, immediate = true },
		['%'] = { func = prims.mod, immediate = true },

		['.'] = { func = prims.dotprint },

		exit = { func = prims.exit, immediate = true },
		defer = { func = prims.defer, immediate = true },
		eval  = { func = prims.eval, immediate = true },
		parse = { func = prims.parse },
		[':'] = { func = prims.define, immediate = true },
		[';'] = { func = prims.enddef, immediate = true },
		immediate = { func = prims.immediate }, -- is this immediate?
		char = { func = prims.char, immediate = true },
	}
end


return prims