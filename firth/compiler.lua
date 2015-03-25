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

	-- make sure we have a compile target
	local cstack = self.cstack
	if not self.compiling then
		if cstack.height == 0 then
			self:newentry()
		else
			local target = cstack:top()
			if type(target) ~= "table" and target.name ~= "[INTERP_BUF]" then
				self:newentry()
			end
		end
	end

	-- interpret/compile each token in line
	while self.line and #self.line > 0 and self.running do
		local tok = self:nexttoken()
		print("TOKEN "..tostring(tok))
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
	self:interpretpending(true)
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
		print("INVOKE IMMEDIATE "..name)
		self:execfunc(entry)
	else
		self:call(name)
	end
end

function compiler:interpretpending(eol)
	print("interpretpending("..tostring(eol)..')')
	local cstack = self.cstack
	if cstack.height > 0 then
		local interp = cstack:top()
		if (type(interp) == "table") and (interp.name == "[INTERP_BUF]") then
			self:buildfunc()
			self:execfunc()

			-- if this was triggered by something other than END-OF-LINE,
			-- then make sure we leave a ready interpret buffer on the cstack.
			if not eol then
				print("REPLACING [INTERP_BUF]")
				self:newentry()
			end
		else
			if eol then
				print("EOL: NOT COMPILING, HAVE CSTACK, BUT NO INTERP_BUF?")
				stringio.print 'c'
				stringio.printstack(cstack)
			else
				print("SKIPPING INTERPRETING "..(interp and interp.name or "nil"))
			end
		end
	end
end

--! @private
local function newcompilebuf()
	return {[[
local compiler = ...
local dictionary, stack = compiler.dictionary, compiler.stack
return function()
	]]}
end

function compiler:newentry(name, stack)
	name = name or "[INTERP_BUF]"
	stack = stack or self.cstack
	local c = stack == self.cstack and 'c' or ''

	stringio.print("PUSHING NEW ENTRY FOR "..name.." onto "..c)
	stack:push{ name = name, compilebuf = newcompilebuf(), calls = {}, calledby = {} }
	stringio.printstack(stack)
--	stringio.printline(self:stacktrace())
end

function compiler:call(word)
	if self.compiling then
		local target = self.cstack:top()
		target.calls[word] = true
		self.dictionary[word].calledby[target.name] = true
	end
	self:append("dictionary[%q].func()",word)
end

--! @private
local function NOP() end

function compiler:buildfunc()
	self.nexttmp = 0 -- TODO: cstack?

	local target = self.cstack:top()
	local name, compilebuf = target.name, target.compilebuf
	local buflen = #compilebuf

	-- don't bother compiling empty buffers (i.e. blank lines)
	if buflen == 1 then
		print("DUMPING "..name..".compilebuf")
		if not self.compiling then
			target.func = nil
		else
			target.func = NOP
		end
		target.compilebuf = nil
		return
	end

	compilebuf[buflen + 1] = "end"
	local luasrc = table.concat(compilebuf, "\n")
	if self.trace then stringio.printline(luasrc, '\n') end
	local func, err = loadstring(luasrc, "__FIRTH__ "..name)
	if func then
		-- exec loaded function to get the actual function we want
		local success, res = pcall(func, self)
		if success then
			target.func = res
			return
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

	-- didn't hit the success path; clean up target
	target.func = nil
	target.calls, target.calledby = nil
end

function compiler:bindfunc()
	local target = self.cstack:pop()
	local name, func = target.name, target.func
	if func then
		print("ADDING "..name.." TO DICTIONARY")
		self.dictionary[name] = target
		self.last = target
	else
		self:runtimeerror("bindfunc", "NIL FUNCTION REF for "..tostring(name))
	end
end

function compiler:execfunc(target)
	target = target or self.cstack:pop()
	local name = target.name
	local func = target.func
	if func then
		print("EXECUTING "..name)
		xpcall(func, self.xperrhandler, self)
	elseif name ~= "[INTERP_BUF]" then -- func == nil, but we have a name for an expected func
		self:runtimeerror("execfunc", "NIL FUNCTION REF for "..tostring(name))
	else
		print("SKIPPING EMPTY [INTERP_BUF]")
	end
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
		kind = (name == "[INTERP_BUF]") and "  <interp>" or "    <word>"
	else
		local fname = frame.name
		if fname then
			name = fname
		else
			local func = frame.func
			if func == self.interpretline then
				name = "interpretline" -- special case; why doesn't this have a name?
			else
				name = tostring(func)
			end
		end
		name = '<'..name..'>'
		kind = "<internal>"
	end
	return '\t'..kind..": "..tostring(name)
end

function compiler:stacktrace()
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
	if not entry then
		self:runtimeerror("immediate", "NO WORD TO SET IMMEDIATE")
	end
	print("SETTING "..entry.name.." IMMEDIATE")
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
	local var = self:newtmp("stack:pop()")
	return var
end

function compiler:pushtmp(var)
	self:append("stack:push(%s)", var)
end

function compiler:append(...)
	local code = string.format(...)
	local target = self.cstack:top()
	print("APPENDING LINE "..code.." TO "..target.name)
	if type(target) ~= "table" or (not target.compilebuf) then self:runtimeerror("append", "INVALID COMPILE TARGET ("..tostring(target)..')') end
	table.insert(target.compilebuf, code)
end


--! @cond
local mt = compiler
mt.__index = mt
compiler = {}
--! @endcond


--! compiler constructor.
function compiler.new()
	-- build compiler object
	local c
	c = {
		dictionary = {},
		stack = stack.new(),
		cstack = stack.new(),
		compiling = false,
		trace = false,
		nexttmp = 0,
		running = true,
		path = "stdin";

		xperrhandler = function(msg)
			stringio.print(string.format("ERROR: %s, ", msg))
			stringio.printstack(c.stack)
			stringio.printline(c:stacktrace())
		end
	}
	setmetatable(c, mt)

	-- initialize dictionary with core words
	prims.initialize(c)
	c:loadfile "firth/prims.firth"

	-- cleanup memory
	collectgarbage()
	collectgarbage()

	return c
end

return compiler