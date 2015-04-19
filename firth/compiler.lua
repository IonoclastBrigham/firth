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
local prims = require "firth.compiler+prims"

local compiler = {
	__FIRTH_INTERNAL__ = "<compiler>" -- used for stacktraces
}
--! @endcond


function compiler:nexttoken(delim)
	local token, rest = stringio.nexttoken(self.line, delim)
	self.line = rest
	return token
end

function compiler:interpretline(line, num)
	self.line = line
	num =  self.compiling and (self.linenum + 1) or num
	self.linenum = num
	self.running = type(line) == "string"

	-- make sure we have a compile target
	if not self.compiling then
		local target = self.target
		if not target or target.name ~= "[INTERP_BUF]" then
--			print("NEW ENTRY FOR [INTERP_BUF]")
			self:create()
		end
	end

	-- interpret/compile each token in line
	while self.line and #self.line > 0 and self.running do
		local tok = self:nexttoken()
--		print("TOKEN "..tostring(tok))
		-- try dictionary lookup
		local val = self.dictionary[tok]
		if val then
			xpcall(self.execword, self.xperrhandler, self, val)
		else
			-- try to parse it as a number
			val = stringio.tonumber(tok)
			if val then
				self:push(val)
			else
				-- error; use xpcall, so we get the stacktrace
				xpcall(self.lookuperror, self.xperrhandler, self, tok, num)
				break
			end
		end
	end

	-- automatic function closing at EOL
	self:interpretpending()
end

function compiler:loadfile(path)
	-- TODO: default/search paths
	local cstack = self.cstack
	local num = 1
	self.running = true
	cstack:push(self.path)
	cstack:push(self.linenum)
	self.path = path
	for line in assert(io.lines(path)) do
		self:interpretline(line, num)
		num = num + 1
		if not self.running then break end
	end
	if self.running and self.cstack.height > 0 then
		local tos = cstack:top()
		if type(tos) == "table"
			and tos.compilebuf and #tos.compilebuf == 1
			and tos.name == "[INTERP_BUF]" then
			cstack:drop()
		end
		self.linenum = cstack:pop()
		self.path = cstack:pop()
	end
end

function compiler:lookup(name)
	local entry = self.dictionary[name]
	if not entry then self:lookuperror(name) end
	return entry
end

function compiler:execword(entry)
	-- TODO: compile mode-specific vocabulary?
	local name = entry.name
	if entry.immediate then
--		print("INVOKE IMMEDIATE "..name)
		self:interpretpending()
		self:execfunc(entry)
	else
		self:call(name)
	end
end

function compiler:interpretpending()
	if self.compiling then return end
	local interp = self.target
	if interp and interp.name == "[INTERP_BUF]" and (#interp.compilebuf > 1) then
--		print("INTERPRETING PENDING")
		self:buildfunc()
		self:execfunc()
		if not self.compiling then self:create() end
--	else
--		print("SKIPPING INTERPRETING PENDING")
	end
end

--! @private
local function newcompilebuf()
	return {[[
local __FIRTH_WORD_NAME__ = %q
local compiler = ...
local dictionary, stack, cstack = compiler.dictionary, compiler.stack, compiler.cstack
%s
%s
return function()]]}
end

function compiler:settarget(newtarget)
	local typ = type(newtarget)
	assert(typ == "table", "INVALID TARGET TYPE "..typ)
	assert(newtarget.compilebuf, "MISSING COMPILEBUF SETTING TARGET "..newtarget.name)

	if self.target then self.cstack:push(self.target) end
	self.target = newtarget
end

function compiler:restoretarget()
	local cstack = self.cstack
	if cstack.height > 0 then
		local tos = cstack:top()
		if type(tos) == "table" and tos.compilebuf then
			self.target = tos
			cstack:drop()
			return
		end
	end
	self.target = nil
end

function compiler:create(name)
	local dopush = (name ~= nil)
	if not name then
		if self.target and self.target.name == "[INTERP_BUF]" then
			return
		else
			name = "[INTERP_BUF]"
		end
	end

--	local c = stack == self.cstack and 'c' or ''
--	stringio.print("PUSHING NEW ENTRY FOR "..name.." onto "..c)
	local entry = {
		name = name, compilebuf = newcompilebuf(),
		calls = { nextidx = 1 }, calledby = {}, upvals = { nextidx = 1 }
	}
	if dopush then
		self.stack:push(entry)
	else
		self:settarget(entry)
	end
--	stringio.printstack(stack)
--	stringio.printline(self:stacktrace())
end

function compiler:call(word)
	local dictionary = self.dictionary
	local target = self.target
	local calls = target.calls
	local callee = self:lookup(word)

	local mappedname = calls[word]
	if not mappedname then
		local index = calls.nextidx
		calls.nextidx = index + 1
		mappedname = "__f"..tostring(index).."__"
		calls[word] = mappedname
		if self.compiling then
			callee.calledby[target.name] = true
		end
	end
	self:append("%s()", mappedname)
end

--! @private
function compiler.NOP() end

--! @private
local function cachedcalls(calls)
	calls.nextidx = nil
	local callbuf = {}
	for word,tmp in pairs(calls) do
		callbuf[#callbuf + 1] = string.format("local %s = dictionary[%q].func", tmp, word)
	end
	return table.concat(callbuf, '\n')
end

local function upvalues(upvals)
	upvals.nextidx = nil
	local buf = { "local upvals = compiler.target.upvals" }
	for tmp,val in pairs(upvals) do
		buf[#buf + 1] = string.format("local %s = upvals[%q]", tmp, tmp)
	end
	local compiledupvals = (#buf > 1) and table.concat(buf, '\n') or ""
	return compiledupvals
end

function compiler:buildfunc()
	self.nexttmp = 0 -- TODO: cstack?

	local target = self.target
	local name, compilebuf = target.name, target.compilebuf
	local buflen = #compilebuf

	-- don't bother compiling empty buffers (i.e. blank lines)
	if buflen == 1 then
--		print("DUMPING "..name..".compilebuf")
		if not self.compiling then
			target.func = nil
		else
			target.func = self.NOP
			target.compilebuf = nil
		end
		return
	end

	compilebuf[1] = compilebuf[1]:format(name,
						cachedcalls(target.calls),
						upvalues(target.upvals))
	compilebuf[buflen + 1] = "end"
	local luasrc = table.concat(compilebuf, '\n')
	local func, err = loadstring(luasrc, "__FIRTH_WORD__ "..name)
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
	local target = self.target
	local name, func = target.name, target.func
	if func then
--		print("ADDING "..name.." TO DICTIONARY")
		self.dictionary[name] = target
		self.funcmap[func] = name
		self.last = target
	else
		self:runtimeerror("bindfunc", "NIL FUNCTION REF for "..tostring(name))
	end
	self:restoretarget()
end

function compiler:execfunc(entry)
	local usecompiletarget = not entry
	if usecompiletarget then
		entry = self.target
	end

	local name = entry.name
	local func = entry.func
	if func then
		if usecompiletarget then
			self:restoretarget()
		end
--		print("EXECUTING "..name)
		xpcall(func, self.xperrhandler, self)
	elseif name ~= "[INTERP_BUF]" then -- func == nil, but we have a name for an expected func
		self:runtimeerror("execfunc", "NIL FUNCTION REF for "..tostring(name))
	else
--		print("SKIPPING EMPTY [INTERP_BUF]")
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

function compiler:clearcompilestate()
	self.linenum = nil
	self.line = nil
	self.compiling = false
	self.target = nil
	self.cstack:clear()
end

function compiler:lookuperror(tok, num)
	local __FIRTH_DUMPTRACE__ = true

	num = num or self.linenum
	local prefix = self.path
	if num then prefix = prefix..':'..num end
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
	self:runtimeerror(prefix, "UNKNOWN WORD '"..tok.."'\n"..suffix, 3)
end

function compiler:runtimeerror(name, msg, level)
	local __FIRTH_DUMPTRACE__ = true

	self:clearcompilestate()
	error("in "..name..': '..msg, level or 2)
end

-- returns a callstack frame iterator
local function frames(start)
	local i = start or 0
	return function()
		local frame = debug.getinfo(i, "Snf") -- source (file), name, function ref
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
	local name, kind

	-- is it a firth-defined word or the interpret buf?
	local source = stringio.split(frame.source, ' ')
	if source[1] == "__FIRTH_WORD__" then
		name = source[2]
		kind = (name == "[INTERP_BUF]") and "  <interp>" or "    <word>"
	else
		-- try to find a reasonable name
		local func = frame.func
		name = self.funcmap[func]
		if name then
			-- in dict/map; this is a prim word
			kind = "    <prim>"
		else
			-- not defined in dict/map; try to extract from callstack
			local fname = frame.name
			if fname then
				name = fname
			else
				-- handle special cases; why don't these have a name?
				-- TODO: if one more of these crops up, do search in a for loop
				if func == self.interpretline then
					name = "interpretline"
				elseif func == self.execword then
					name = "execword"
				else
					name = tostring(func)
				end
			end

			-- is it a firth internal component?
			for i = 1, math.huge do -- "counted forever"
				local lname, lvalue = debug.getlocal(level, i)
				if not lname then break end
				if lname == "self" and type(lvalue) == "table" then
					kind = lvalue.__FIRTH_INTERNAL__
					break
				end
			end
		end

		-- didn't find a specific type, mark it as "internal"
		kind = kind or "<internal>"
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
	return "call trace:\n"..table.concat(stackframes, '\n')
end

function compiler:assert(cond, name, msg)
	local __FIRTH_DUMPTRACE__ = true

	if not cond then self:runtimeerror(name, msg) end
end

function compiler:cassert(tmpcond, msg)
	self:append("compiler:assert(%s, __FIRTH_WORD_NAME__, %q)", tmpcond, msg)
end

function compiler:immediate(word)
	local entry
	if word then
		entry = self:lookup(word)
	else
		entry = self.last
		self:assert(entry, "immediate", "NO ENTRY TO SET IMMEDIATE")
	end
--	print("SETTING "..entry.name.." IMMEDIATE")
	entry.immediate = true
end

--! Compiles code to push value.
--! @see pushstring()
function compiler:push(val)
	self:append("stack:push(%s)", val)
end

--! Compiles code to push correctly quoted string value.
--! @see push()
function compiler:pushstring(str)
	str = string.format("%q", str):gsub("\\\\", "\\") -- restore backslashes
	self:push(str)
end

--! Compiles code to push a non-stringifiable value, which must be closed over.
function compiler:pushupval(val)
	local upvals = self.target.upvals
	local idx = upvals.nextidx
	upvals.nextidx = idx + 1
	local name = "__uv"..tostring(idx).."__"
	upvals[name] = val
	self:push(name)
end

function compiler:newtmp(initialval)
	local nexttmp = self.nexttmp
	local var = string.format("__tmp%d__", nexttmp)
	self.nexttmp = nexttmp + 1
	self:append("local %s = %s", var, tostring(initialval))

	return var
end

function compiler:newtmpformat(str, ...)
	return self:newtmp(str:format(...))
end

function compiler:newtmpstring(str)
	str = string.format("%q", str):gsub("\\\\", "\\") -- restore backslashes
	return self:newtmp(str)
end

function compiler:poptmp()
	local var = self:newtmp("stack:pop()")
	return var
end

function compiler:toptmp()
	local var = self:newtmp("stack:top()")
	return var
end

function compiler:append(...)
	local code = '\t'..string.format(...)
	local target = self.target
--	print("APPENDING LINE "..code.." TO "..target.name)
	if type(target) ~= "table" or (not target.compilebuf) then
--		print(table.concathash(target))
		self:runtimeerror("append", "INVALID COMPILE TARGET ("..tostring(target)..')')
	end
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
		funcmap = {},
		stack = stack.new(),
		cstack = stack.new(),
		compiling = false,
		target = nil,
		tracing = false,
		nexttmp = 0,
		running = true,
		path = "stdin";

		xperrhandler = function(msg)
			stringio.printline(string.format("ERROR: %s", msg))
			stringio.print 'stack : '
			stringio.printline(tostring(c.stack))
			stringio.print 'cstack: '
			stringio.printline(tostring(c.cstack))
			stringio.printline(c:stacktrace())
		end
	}
	setmetatable(c, mt)

	-- initialize dictionary with core words
	prims.initialize(c)
	c:loadfile "firth/core.firth"

	-- cleanup memory
	collectgarbage()
	collectgarbage()

	return c
end

return compiler