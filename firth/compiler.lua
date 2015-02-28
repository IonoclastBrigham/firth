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
			self:execword(tok, val)
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

function compiler:execword(name, entry)
	-- TODO: compile mode-specific vocabulary?
	if not self.compiling or entry.immediate then
		-- interpret mode or immediate found
		local success, err = pcall(entry.func, self)
		if not success then stringio.print(err) end
	else
		-- compile mode
		self:call(name)
	end
end

function compiler:newfunc(word)
	self.last = word
	self.compiling = true
	self:append("return function(compiler)")
end

function compiler:call(func)
	self:append("compiler.dictionary['%s'].func(compiler)", func)
end

function compiler:done()
	self:append("end")
	--stringio.print(self.last.." = "..self.compilebuf)
	---[[
	local func, err = loadstring(self.compilebuf)
	if not err then
		local success, res = pcall(func, self)
		if success then
			self.dictionary[self.last] = { func=res }
		else
			stringio.print(res)
		end
	else
		stringio.print(err)
	end
	--]]
	self.compilebuf = nil
	self.compiling = false
	self.nexttmp = 0
end

function compiler:immediate(word)
	self.dictionary[word or self.last].immediate = true
end

function compiler:push(num)
	if self.compiling then
		-- compile mode
		self:pushtmp(num)
	else
		-- interpret mode
		self.stack:push(num)
	end
end

function compiler:error(tok)
	stringio.print("Error: unknown word ( "..tok.." )")
	self.line = nil
	self.compilebuf = nil
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
	self:append("compiler:push(%s)", var)
end

function compiler:append(...)
	local code = string.format(...)
	if self.compilebuf then
		self.compilebuf = string.format("%s\n%s", self.compilebuf, code)
	else
		self.compilebuf = code
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
		dictionary = prims.initialize(),
		compiling = false,
		nexttmp = 0,
		running = true,
	}
	
	return setmetatable(c, mt)
end

return compiler