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

function compiler:interpretline(line, num)
	self.line = line
	self.running = type(line) == "string"
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
		self:interpretline(line, num)
		num = num + 1
		if not self.running then break end
	end
	self.path = self.cstack:pop()
end

function compiler:execword(entry)
	-- TODO: compile mode-specific vocabulary?
	local name = entry.name
	if entry.immediate then
--		print("IMMEDIATE "..name..'{'..table.concathash(entry, ' ')..'}')
		self:execfunc(name, entry[name])
	else
		self:call(name)
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
	self:append("compiler.dictionary[%q][%q](compiler)", word, word)
end

function compiler:currentbuf()
	return self.last.name, self.last.compilebuf
end

--! @private
local function NOP() end

function compiler:buildfunc(name, compilebuf)
	self.nexttmp = 0 -- TODO: cstack?

	-- don't bother compiling empty buffers (i.e. blank lines)
	if #compilebuf == 1 then
		if not self.compiling then return nil, nil end
		return name, NOP
	end

	table.insert(compilebuf, "end")
	local luasrc = table.concat(compilebuf, "\n")
	if self.trace then stringio.printline(luasrc, '\n') end
	local func, err = loadstring(luasrc, "__FIRTH__ "..name)
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
		self.last[name] = func
		self.dictionary[name] = self.last
	else
		self:runtimeerror("bindfunc", "NIL FUNCTION REF")
	end
end

function compiler:execfunc(name, func)
	if func then
		xpcall(func, self.xperrhandler, self)
	elseif name then -- func == nil, but we have a name
		self:runtimeerror("execfunc", "NIL FUNCTION REF")
	end
end

function compiler:interpretpending()
	local scratch = self.scratch
	self.scratch = {"return function(compiler)"}
	self:execfunc(self:buildfunc("[INTERP_BUFFER]", scratch))
end

local function sortmatches(buckets, tok)
	local result = {}

	for i, matches in ipairs(buckets) do
		local idx = i + 1
		local ch = tok:sub(idx, idx)
		table.sort(matches, function(a, b)
			return (a:sub(idx, idx) == ch) and (b:sub(idx, idx) ~= ch)
		end)
	end

	for _, matches in ipairs(buckets) do
		for _, match in ipairs(matches) do
			table.insert(result, match)
		end
	end

	if #result == 0 then result[1] = "(NO SUGGESTIONS FOUND)" end
	return result
end

function compiler:lookuperror(tok, num)
	self.line = nil
	self.compiling = false

	local prefix = "in "..self.path..':'
	if num then prefix = prefix..num..':' end
	local buckets = {}
	for k,v in pairs(self.dictionary) do
		for i = 1, #tok do
			buckets[i] = buckets[i] or {}
			if i > #k then break end
			if tok:sub(i,i) == k:sub(i,i) then
				table.insert(buckets[i], k..(v.immediate and " (immediate)" or ""))
				break
			end
		end
	end
	local suffix = "Did You Mean..?\n\t"..table.concat(sortmatches(buckets, tok), "\n\t")
	self:runtimeerror("interpretline", "UNKNOWN WORD '"..tok.."'\n"..suffix)
end

function compiler:runtimeerror(name, msg)
	local __FIRTH_DUMPTRACE__ = true
	error(" in "..name..': '..msg, 2)
end

-- returns a stack frame iterator
local function frames(start)
	local i = start or 0
	return function()
		local frame = debug.getinfo(i, "Snf") -- source, name, function ref
		i = i + 1
		return frame
	end
end

-- returns true if local __FIRTH_DUMPTRACE__ == true, at frame frameidx.
-- this is a signal that we've hit an internal error mechanism, and the
-- actual error occurred one frame below that.
local function dumptrace(frameidx)
	for i = 1, math.huge do -- "counted forever"
		local name, value = debug.getlocal(frameidx, i)
		if not name then break end
		if (name == "__FIRTH_DUMPTRACE__") and (value == true) then return true end
	end
	return false
end

function compiler:traceframe(frame, level)
	local source = stringio.split(frame.source, ' ')
	local name, kind
	if source[1] == "__FIRTH__" then
		name = source[2]
		kind = (name == "[INTERP_BUFFER]") and "    <anon>" or "    <word>"
	else
		local fname = frame.name
		if fname then
			name = fname
		else
			local func = frame.func
			if func == self.interpretline then
				name = "interpretline"
			else
				name = tostring(func)
			end
		end
		name = '<'..name..'>'
		kind = "<internal>"
	end
	return '\t'..kind..": "..tostring(name)
end

function compiler:stacktrace(msg)
	local __FIRTH_DUMPTRACE__ = true

	local stackframes = {}
	local i = 2
	for frame in frames(i) do
		if dumptrace(i) then
			stackframes = {}
		elseif frame.what == "Lua" then
			stackframes[#stackframes+1] = self:traceframe(frame, i)
		end
		i = i + 1
	end
	return "Call Trace:\n"..table.concat(stackframes, '\n')
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
	local c
	c = {
		stack = stack.new(),
		cstack = stack.new(),
		dictionary = prims.initialize(),
		compiling = false,
		trace = false,
		scratch = {"return function(compiler)"},
		nexttmp = 0,
		running = true,
		path = "stdin";

		xperrhandler = function(msg)
			stringio.printline(string.format("ERROR: %s, stack: [%s]",
					msg, table.concat(c.stack, ' ')))
			stringio.printline(c:stacktrace(msg))
		end
	}
	setmetatable(c, mt)
	c:loadfile "firth/prims.firth"
	return c
end

return compiler