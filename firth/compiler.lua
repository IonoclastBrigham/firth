--------------------------------------------------------------------------------
--! @file compiler.lua
--! @brief Source compiler for Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015 Brigham Toskin
--! 
--! <p>This file is part of the Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--! @see stringio.lua
--------------------------------------------------------------------------------


--! @cond
local stringio = require "firth.stringio"
local stack = require "firth.stack"
local prims = require "firth.compiler-prims" -- TODO: "compiler.prims"?

local compiler = {}
--! @endcond


function compiler:nexttoken(delim)
	local token, rest = stringio.nexttoken(self.line, delim)
	self.line = rest
	return token
end

function compiler:parse(line)
	self.line = line
	self.running = true
	while self.line and #self.line > 0 and self.running do
		local tok = self:nexttoken()
		local val = self.dictionary[tok]
		if val then
			self:execword(val)
		else
			val = stringio.tonumber(tok)
			if val then
				self:push(val)
			else
				self:error(tok)
				break
			end
		end
	end
end

function compiler:loadfile(path)
	-- TODO: default/search paths
	for line in assert(io.lines(path)) do self:parse(line) end
end

function compiler:execword(entry)
	-- TODO: compile mode-specific vocabulary?
	if not self.compiling or entry.immediate then
		-- interpret mode or immediate found
		local success, err = pcall(entry.func, self)
		if not success then stringio.printline(err) end
	else
		-- compile mode
		self:call(entry.name)
	end
end

function compiler:newfunc(word)
	self.last = { name = word, compilebuf = "", calls = {}, calledby = {} }
	self.compiling = true
end

function compiler:call(word)
	if self.compiling then
		self.last.calls[word] = true
		self.dictionary[word].calledby[self.last.name] = true
		self:append("compiler.dictionary['%s'].func(compiler)", word)
	else
		if type(word) ~= "function" then
			word = self.dictionary[word].func
		end
		local success, err = pcall(word, self)
		if not success then stringio.printline(err) end
	end
end

function compiler:done()
	local last = self.last
	if self.trace then stringio.printline(last.compilebuf) end
	local luasrc = "return function(compiler)"..last.compilebuf.."\nend"
	local func, err = loadstring(luasrc)
	if not err then
		local success, res = pcall(func, self)
		if success then
			self.last.func = res
			self.dictionary[last.name] = last
		else
			stringio.printline("Compile Error:")
			stringio.printline(res)
			stringio.printline(luasrc)
		end
	else
		stringio.printline("Compile Error:")
		stringio.printline(err)
		stringio.printline(luasrc)
	end
	self.compiling = false
	self.nexttmp = 0
end

function compiler:immediate(word)
	local entry = (word and self.dictionary[word] or self.last)
	entry.immediate = true
end

--! Either compiles push code, or directly pushes value.
--! @see pushstring()
function compiler:push(val)
	if self.compiling then
		self:pushtmp(val)
	else
		self.stack:push(val)
	end
end

--! Either compiles push code for quoted value, or directly pushes value.
--! @see push()
function compiler:pushstring(str)
	if self.compiling then
		str = "'"..str.."'"
	end
	self:push(str)
end

function compiler:error(tok)
	stringio.printline("Error: unknown word ( "..tok.." )")
	self.line = nil
	self.compiling = false
end

function compiler:newtmp()
	local nexttmp = self.nexttmp
	local var = string.format("__tmp%d__", nexttmp)
	self.nexttmp = nexttmp + 1
	self:append("local %s", var)

	return var
end

function compiler:poptmp()
	local var = self:newtmp()
	self:append("%s = compiler.stack:pop()", var)
	return var
end

function compiler:pushtmp(var)
	self:append("compiler.stack:push(%s)", var)
end

function compiler:append(...)
	local code = string.format(...)
	local last = self.last
	last.compilebuf = string.format("%s\n%s", last.compilebuf, code)
end


--! @cond
local mt = compiler
mt.__index = mt
compiler = {}
--! @endcond


--! compiler constructor.
function compiler.new()
	local c = {
		stack = stack.new(),
		dictionary = prims.initialize(),
		compiling = false,
		nexttmp = 0,
		running = true,
	}
	setmetatable(c, mt)
	c:loadfile "firth/prims.firth"
	return c
end

return compiler