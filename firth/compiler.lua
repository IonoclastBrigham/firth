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

function compiler:parse(line, num)
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
				self:lookuperror(tok, num)
				break
			end
		end
	end
	-- automatic function closing at EOL
	if #self.scratch > 0 and not self.compiling then self:interpretpending() end
end

function compiler:loadfile(path)
	-- TODO: default/search paths
	local num = 1
	self.running = true
	self.cstack:push(self.path)
	self.path = path
	for line in assert(io.lines(path)) do
		self:parse(line, num)
		num = num + 1
		if not self.running then break end
	end
	self.path = self.cstack:pop()
end

function compiler:execword(entry)
	-- TODO: compile mode-specific vocabulary?
	if entry.immediate then
		local success, err = pcall(entry.func, self)
		if not success then self:runtimeerror(entry.name, err) end
	else
		self:call(entry.name)
	end
end

function compiler:newentry(name)
	self.last = { name = name, compilebuf = {"return function(compiler)"}, calls = {}, calledby = {} }
end

function compiler:call(word)
	if self.compiling then
		self.last.calls[word] = true
		self.dictionary[word].calledby[self.last.name] = true
	end
	self:append("compiler.dictionary[%q].func(compiler)", word)
end

function compiler:currentbuf()
	return self.last.name, self.last.compilebuf
end

function compiler:buildfunc(name, compilebuf)
	self.nexttmp = 0
	if not self.compiling and #compilebuf == 1 then return nil, nil end
	table.insert(compilebuf, "end")
	local luasrc = table.concat(compilebuf, "\n")
	if self.trace then stringio.printline(luasrc, '\n') end
	local func, err = loadstring(luasrc, name)
	if func then
		-- exec returned function to the the actual function we want
		local success, res = pcall(func, self)
		if success then
			return name, res
		else
			stringio.printline("Compile Error (buildfunc):")
			stringio.printline(res)
			stringio.printline(luasrc)
		end
	else
		stringio.printline("Compile Error (loadstring):")
		stringio.printline(err)
		stringio.printline(luasrc)
	end
	return nil, nil
end

function compiler:bindfunc(name, func)
	if func then
		self.last.func = func
		self.dictionary[name] = self.last
	end
end

function compiler:execfunc(name, func)
	if func then
		local success, err = pcall(func, self)
		if not success then self:runtimeerror(name, err) end
	end
end

function compiler:interpretpending()
	local scratch = self.scratch
	self.scratch = {"return function(compiler)"}
	self:execfunc(self:buildfunc("__SCRATCH__", scratch))
end

function compiler:immediate(word)
	local entry = (word and self.dictionary[word] or self.last)
	entry.immediate = true
end

--! Either compiles push code, or directly pushes value.
--! @see pushstring()
function compiler:push(val)
	-- TODO: redundant, now?
	self:pushtmp(val)
end

--! Either compiles push code for quoted value, or directly pushes value.
--! @see push()
function compiler:pushstring(str)
	str = string.format("%q", str):gsub("\\\\", "\\") -- restore backslashes
	self:push(str)
end

function compiler:lookuperror(tok, num)
	self.line = nil
	self.compiling = false
	stringio.print(self.path..':')
	if num then stringio.print(num..": ") end
	error("Error: unknown word '"..tok.."'")
end

function compiler:runtimeerror(name, msg)
	error("Runtime error: '"..tostring(name).."': "..msg, 2)
end

function compiler:newtmp(initialval)
	local nexttmp = self.nexttmp
	local var = string.format("__tmp%d__", nexttmp)
	self.nexttmp = nexttmp + 1
	self:append("local %s = %s", var, tostring(initialval))

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
	if self.compiling then
		table.insert(self.last.compilebuf, code)
	else
		table.insert(self.scratch, code)
	end
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
		cstack = stack.new(),
		dictionary = prims.initialize(),
		compiling = false,
		trace = false,
		scratch = {"return function(compiler)"},
		nexttmp = 0,
		running = true,
		path = "stdin",
	}
	setmetatable(c, mt)
	c:loadfile "firth/prims.firth"
	return c
end

return compiler