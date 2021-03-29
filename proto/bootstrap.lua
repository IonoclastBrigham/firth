--------------------------------------------------------------------------------
--! @file
--! @brief prototype :Firth bootstrap script.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2021 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


--! @cond

-- compat defs for different versions of PUC-Rio Lua
package.path = "./?/init.lua;"..package.path
bit = require "compat.bit" -- Lua@5.2 bit32; Lua@5.4 operators
loadstring = loadstring or load -- Lua@5.3+
setfenv = setfenv or require 'compat.compat_env'.setfenv  -- Lua@5.2+
unpack = unpack or table.unpack  -- Lua@5.2+
tonumber = require "compat.tonumber" -- Lua@5.2+

-- cache common lua globals before nuking the environment
local assert, error = assert, error
local debug = debug
local getmetatable, setmetatable = getmetatable, setmetatable
local ipairs, pairs = ipairs, pairs
local loadstring = loadstring
local math = math
local os = os
local print = print
local rawget = rawget
local require = require
local setfenv = setfenv
local select, table, unpack = select, table, unpack
local tostring, tonumber = tostring, tonumber
local type = type
local pcall, xpcall = pcall, xpcall

local bit = bit
local bitand, bitor, bitxor, bitnot = bit.band, bit.bor, bit.bxor, bit.bnot

-- firth imports
local fli = require "firth.fli"
local stringio = require "firth.stringio"
local stack	= require "firth.stack"
local fstack   = require "firth.fstack"
require "firth.luex"

-- set up Lua global namespace as firth dictionary / global environment
local _lua = fli.inject({}, _G)
_lua._G, _lua.arg = nil, nil
local _G  = { Lua =  _lua }
_G.dictionary = _G
setfenv(1, _G)

fli.wrapglobals(Lua)
fli.maplua(dictionary, Lua) -- TODO: optional/upon request?
fli.inject(dictionary, fstack)
fli.inject(dictionary, fli) -- do we want to do this ???

--! @endcond


-- global parser / interpreter / compiler state
intptr_running = false
cstack = stack.new()
rstack = stack.new()
meta = setmetatable({}, { __mode = "k" })
immediates = setmetatable({}, { __mode = "k" })

--! @private
local entrymt = {
	__tostring = function(t)
		return ("{%s}"):format(t.name)
	end
}
entrymt.__index = entrymt

-- Error Handling --------------------------------------------------------------

local function _reverse_r(i, ...)
	local cnt = height(...) - i
	if cnt > 0 then
		return select(cnt, ...), _reverse_r(i + 1, ...)
	end
end

local function prepstack(...)
	if select('#', ...) == 0 then return '∅ ' end

	return mapstack(
		function(x)
			-- pass through quote before tostring; quote will quote strings
			-- but leave e.g. numbers untouched.
			-- then we convert everything for printing.
			return tostring(quote(x)):gsub('\\\n', '\\n'):gsub('\\9', '\\t').." "
		end,
		_reverse_r(0, ...)
	)
end

local frozen_stack = {} -- for error reporting

function xperrhandler(msg)
	stringio.printline(("ERROR: %s"):format(msg))
	stringio.printline(("while running %s:%d"):format(current_infile, line_num))
	local stackstring = '[ '..prepstack(unpack(frozen_stack))..' ]'
	stringio.printline('stack : '..stackstring)
	stringio.printline('cstack: '..tostring(cstack))
	stringio.printline('rstack: '..tostring(rstack))
	stringio.printline(stacktrace(3))

	return cclearstate(false, unpack(frozen_stack))
end

-- ( n -- s )
function stacktrace(i, ...)
	return "call"..debug.traceback("", i or 2):sub(2), ...
end

-- (n s1 s2 -- 0 )
local function runtime_err(name, msg, level, ...)
	local __FIRTH_DUMPTRACE__ = true

	frozen_stack = {...}
	error("in "..name..': '..msg, level or 2)
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

local LOOKUP_ERR_MSG = "%s is undefined\n%s"

-- ( n s -- 0 )
local function lookup_err(tok, throw, ...)
	local __FIRTH_DUMPTRACE__ = true -- TODO ???

	local path = current_infile--:gsub("^(.-)(/?)([^/]*)$", "%1%2")
	if not path or #path == 0 then path = "./" end
	local prefix = path..':'..line_num
	local buckets = {}
	for k,v in pairs(dictionary) do
		for i = 1, #tok do
			buckets[i] = buckets[i] or {}
			if i > #k then break end
			if tok:sub(i,i) == k:sub(i,i) then
				table.insert(buckets[i], k)--..(immediates[v] and " (immediate)" or ""))
				break
			end
		end
	end

	local suggestions = sortmatches(buckets, tok)
	local count = math.min(#suggestions, 5)
	suggestions = table.slice(suggestions, 1, count)
	local suffix = "Did You Mean..?\n\t"..table.concat(suggestions, "\n\t")
	local msg = LOOKUP_ERR_MSG:format(tok, suffix)
	if throw then
		return runtime_err(prefix, msg, 2, ...)
	else
		stringio.stderr():write(msg.."\n")
		return ...
	end
end
dictionary['lookup_err'] = fli.wrapfunc(lookup_err, 2, 0)

debuglogs = false
local function debug(str, ...)
	if not debuglogs then return end

	if select("#", ...) > 0 then str = str:format(...) end
	stringio.printline("🐛 "..str)
end


-- core primitives -------------------------------------------------------------

STDIN = fli.wrapfunc(stringio.stdin, 0)
STDOUT = fli.wrapfunc(stringio.stdout, 0)
STDERR = fli.wrapfunc(stringio.stderr, 0)

input  = fli.wrapfunc(stringio.input, 0, 1)
output = fli.wrapfunc(stringio.output, 0, 1)
useinput  = fli.wrapfunc(stringio.input, 1, 0)
useoutput = fli.wrapfunc(stringio.output, 1, 0)

-- ( s -- ) ( Out: s )
dictionary['.raw'] = function(str, ...)
	assert(type(str) == "string", "NOT A STRING")
	stringio.print(str)
	return ...
end

-- ( -- )
dictionary[".S"] = function(...)
	stringio.print(prepstack(...))
	return ...
end

-- ( s -- s' )
quote = fli.wrapfunc(stringio.quote, 1)

-- ( s -- s' )
trim = fli.wrapfunc(stringio.trim, 1)

-- ( x -- n|nil )
dictionary["string>number"] = fli.wrapfunc(stringio.tonumber, 1)

-- ( s -- b )
function defined(name, ...)
	return (rawget(dictionary, name) ~= nil), ...
end

-- ( word -- x )
function lookup(word, ...)
	return dictionary[word], ...
end

-- ( word -- x )
function resolve(word, ...)
	if defined(word) then return lookup(word, ...) end

	local val = stringio.tonumber(word) or stringio.toboolean(word)
	if val ~= nil or word == "nil" then return val, ... end

	-- error; use xpcall, so we get the stacktrace
	xpcall(lookup_err, xperrhandler, word, true, ...)
end

--! ( -- c ) ( TS: c ) ;immed
function char(...)
	local word = parse("%s")
	if #word == 0 then return cpush("", ...) end -- TODO: nil? error?

	local ch = word:sub(1, 1)
	if ch == "%" or ch == "\\" then
		ch = word:sub(1, 2)
		if ch == "\\n" then
			ch = "\n"
		elseif ch == "\\t" then
			ch = "\t"
		elseif ch == '\\"' then
			ch = '"'
		end
	end

	return cpush(ch, ...)
end
immediates[char] = true

-- ( n*x s1 -- s2)
function fmt(str, ...)
	str = str:gsub("\\t", "\t"):gsub("\\n", "\n"):gsub('\\"', '"')
	local _, count = str:gsub("%%[^%%]", "")
	return str:format(...), select(count + 1, ...)
end

-- ( s1 -- s2 )
function parse(delim, ...)
	if parse_pos > #tok_stream then return '', ... end

	local word, endpos = stringio.nexttoken(tok_stream, delim, parse_pos)
	parse_pos  = endpos
	return word, ...
end

--! ( pattern -- tok )
function parsematch(pattern, ...)
	local success, word, endpos = pcall(stringio.matchtoken, tok_stream, pattern, parse_pos)
	assert(success, word)
	parse_pos = endpos
	return word, ...
end

-- ( n -- ) ( TS: -n )
function backtrack(n, ...)
	parse_pos = math.max(parse_pos - n, 0)
	debug("BACKTRACKING TO '%s'...", tok_stream:sub(parse_pos, parse_pos + 10))
	return ...
end

-- ( s? -- b )
function nonempty(str, ...)
	return (type(str) == "string" and #str > 0), ...
end

-- ( s -- )
function countlines(str, ...)
	-- any '\r's will always predeced '\n'
	local _, newlines = str:gsub("\n", "")
	line_num = line_num + newlines
	return ...
end

-- ( b -- )
function cclearstate(die, ...)
	debug("CLEARING COMPILE STATE!!!!!!!")

	current_infile = "{STDIN}"
	stringio.input(stringio.stdin())

	tok_stream = ""
	intptr_running = not die
	parse_pos = 1
	line_num = 1

	compiling = false
	compile_target = nil

	cstack:clear()

	return ...
end

function pushinputstate(...)
	cstack:push(current_infile)
	stringio.flush()
	cstack:push(stringio.input())

	return ...
end

function popinputstate(...)
	stringio.flush()
	stringio.input(cstack:pop())
	current_infile = cstack:pop()

	return ...
end

function pushparsestate(...)
	cstack:push(tok_stream)
	cstack:push(intptr_running)
	cstack:push(parse_pos)
	cstack:push(line_num)

	return ...
end

function popparsestate(...)
	line_num = cstack:pop()
	parse_pos = cstack:pop()
	intptr_running = cstack:pop()
	tok_stream = cstack:pop()

	return ...
end

function pushcompilestate(...)
	cstack:push(compiling)
	cstack:push(compile_target)

	return ...
end

function popcompilestate(...)
	compile_target = cstack:pop()
	compiling = cstack:pop()

	return ...
end

-- ( s -- entry )
function create(name, ...)
	debug("CREATE %q", name)
	local entry = { name = name }
	setmetatable(entry, entrymt)
	-- dictionary[name] = entry
	return entry, ...
end

dictionary["compile_target.NAME"] = "name"
dictionary["compile_target.XT"] = "xt"
dictionary["compile_target.COMPILEBUF"] = "compilebuf"
dictionary["compile_target.SRCBUF"] = "srcbuf"

-- ( entry -- )
function compile(newtarget, ...)
	assert(getmetatable(newtarget) == entrymt, "Invalid Compile Target")

	-- TODO: EVERYTHING LIVES ON CSTACK SO LAMBDAS CAN LIVE INSIDE FUNCTIONS??
	pushcompilestate()
	compile_target = newtarget
	compiling = true
	newtarget.compilebuf = {}
	newtarget.srcbuf = {}
	return ...
end

--! Creates a lambda that (closure) captures `TOS` (i.e. 1 item).
--!
--! @returns      * (forwarded return from inner lambda compilation, minus xt).
--! @compiles     a call to an anonymous function that consumes `TOS`
--!               and leaves a closure that calls the original compiled
--!               lambda with th captured values of TOS on the stack.
--! @immediate
-- ( x -- * )
-- debuglogs = false
dictionary[')[1];'] = function(...)
	-- _capture is just here to make sure the stack
	-- is properly forwarded through {:(}.
	local function _capture(...)
		return ccall(function(closurethread, val,...)
			return function(...)
				return closurethread(val, ...)
			end, ...
		end, ...)
	end

	return _capture(dictionary[');'](...))
end
immediates[dictionary[')[1];']] = true

-- ( -- ) ;immed
function interpret(...)
	compiling = false
	return ...
end
immediates[interpret] = true

-- Can't be a word because recursion depends on params in chronological order
local function _thread_r(xt1, xt2, ...)
	-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	-- TODO: normalize cappend to always use a metatable, always use xt:thread()
	-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	if not xt2 then
		if getmetatable(xt1) then
			return xt1:thread()
		else
			return xt1
		end
	end

	local next = _thread_r(xt2, ...)
	local thr
	if getmetatable(xt1) then
		thr = xt1:thread(next)
	else
		thr = function(...) return next(xt1(...)) end
	end

	return thr
end

-- ( -- entry )
function buildfunc(...)
	local  entry = compile_target
	popcompilestate()

	if jmpcont then ccall(jmpcont) end
	local name, compilebuf = entry.name, entry.compilebuf
	debug("BUILDING %s", name)
	entry.xt = (#compilebuf > 0) and _thread_r(unpack(compilebuf)) or function(...) return ... end

	return entry, ...
end

-- ( entry -- )
function bindfunc(entry, ...)
	dictionary[entry.name] = entry.xt
	meta[entry.name] = entry
	meta[entry.xt] = entry
	return ...
end

-- ( * xt -- * )
function execute(xt, ...)
	return xt(...)
end

-- ( word -- ) ( SB: word )
function srcappend(word, ...)
	table.insert(compile_target.srcbuf, word)
	return ...
end

-- ( xt -- ) ( CB: xt )
function cappend(xt, ...)
	table.insert(compile_target.compilebuf, xt)
	return ...
end

local binopmt = {
	thread = function(self, next)
		local src = next and [[
			local next = ...
			return function(TOS, NOS, ...)
				return next(NOS %s TOS, ...)
			end
		]] or [[
			return function(TOS, NOS, ...)
				return NOS %s TOS, ...
			end
		]]
		return loadstring(src:format(self.op))(next)
	end,
	exec = function(self, b, a, ...)
		local src = ([[
			return function(_, TOS, NOS, ...) return NOS %s TOS, ... end
		]])
		self.exec = loadstring(src:format(self.op))()
		return self:exec(b, a, ...)
	end
}
binopmt.__index = binopmt
local opcache = {}
local function binop(op)
	if not opcache[op] then
		opcache[op] = setmetatable({op = op}, binopmt)
	end
	return opcache[op]
end

-- ( op -- ) ( CB: {op} ) ;immed
function cbinop(op, ...)
	op = binop(op)
	if compiling then
		return cappend(op, ...)
	else
		return op:exec(...)
	end
end

-- TODO: replace with unop impl.
dictionary["not"] = function(b, ...)
	return not b, ...
end

-- (f -- * ) ( CB: xt ) ;immed
function ccall(func, ...)
	local xt
	if type(func) == "string" then
		xt = compiling and function(...) return (dictionary[func])(...) end or dictionary[func]
	elseif type(func) == "function" then
		xt = func
	else
		runtime_err("ccall", ("INVALID ARGUMENT: '%s'"):format(func))
	end

	if compiling then
		return cappend(xt, ...)
	else
		return xt(...)
	end
end

-- ( x -- ) ( CB: push(x) ) ;immed
function cpush(val, ...)
	if compiling then
		local function pushval(...)
			return val, ...
		end
		cappend(pushval)
		return ...
	else
		return val, ...
	end
end

-- NOTE: not a word; we use `fli` to wrap it for :Firth use.
local function cbeginblock(name, completion)
	compile(create(name)) -- compile pushes prev compile state
	cstack:push(completion)
end
dictionary['cbeginblock'] = fli.wrapfunc(cbeginblock, 2, 0)

function cendblock(...)
	local completion = cstack:pop()
	local do_call, thread = completion(buildfunc().xt) -- pops prev compile state
	if do_call then
		return ccall(thread, ...)
	else
		return thread, ...
	end
end

-- ( cond -- )
dictionary['if'] = function(...)
	cbeginblock("[[IF]]", function(thenthread)
		return true, function(cond, ...)
			if cond then return thenthread(...) else return ... end
		end
	end)
	return ...
end
immediates[dictionary['if']] = true

-- ( -- )
dictionary['else'] = function(...)
	-- restore compile state for cbeginblock
	cstack:drop() -- drop basic if-then completion
	local thenthread = buildfunc().xt

	-- replacement completion for end
	cbeginblock("[[ELSE]]", function(elsethread)
		return true, function(cond, ...)
			if cond then
				return thenthread(...)
			else
				return elsethread(...)
			end
		end
	end)
	return ...
end
immediates[dictionary['else']] = true

-- ( -- )
dictionary['end'] = function(...)
	return cendblock(...)
end
immediates[dictionary['end']] = true

-- ( nstart nlimit -- )
dictionary['for'] = function(...)
	cbeginblock("[[FOR]]", function(forthread)
		return true, function(limit, start, ...)
			assert(limit % 1 == 0 and start % 1 == 0, "Arguments must be integers")
			local step = sign(limit - start)
			local function _for_r(i, ...)
				if i == limit then
					return forthread(i, ...)
				else
					return _for_r(i + step, forthread(i, ...))
				end
			end
			return _for_r(start, ...)
		end
	end)
	return ...
end
immediates[dictionary['for']] = true

-- ( iterable -- )
function each(...)
	cbeginblock("[[EACH]]", function(eachthread)
		return true, function(iterable, ...)
			-- TODO: support strings and iterator xts on TOS
			-- TODO: function spairs(str) return function(str, idx) local c = str:sub(idx+1, idx+1); if  #c == 0 then return nil, nil else return idx+1, c end end, str, 0 end
			local newitr = getmetatable(iterable) and getmetatable(iterable).__itr
			assert(
				newitr or type(iterable) == "table",
				"Argument must be iterable"
			)
			newitr = newitr or (#iterable > 0 and ipairs) or pairs
			local itr, _, idx = newitr(iterable)
			local function _each_r(...)
				local val
				idx, val = itr(iterable, idx)
				if idx == nil then return ... end
				return _each_r(eachthread(val, idx, ...))
			end
			return _each_r(...)
		end
	end)
	return ...
end
immediates[each] = true

-- ( cond -- )
dictionary['while'] = function(...)
	-- TODO: a coopt the block thread to allow a `WHILE cond DO xxx END` form..?
	cbeginblock("[[WHILE]]", function(whilethread)
		local function _while_r(cond, ...)
			if cond then return _while_r(whilethread(...)) end
			return ...
		end
		return true, _while_r
	end)
	return ...
end
immediates[dictionary['while']] = true

function loops(...)
	cbeginblock("[[LOOPS]]", function(loopsthread)
		local function _loops_r(count, ...)
			if count < 1 then return ... end
			return _loops_r(count - 1, loopsthread(...))
		end
		return true, _loops_r
	end)
	return ...
end
immediates[loops] = true

function forever(...)
	cbeginblock("[[FOREVER]]", function(foreverthread)
		local function _forever_r(...)
			return _forever_r(foreverthread(...))
		end
		return true, _forever_r
	end)
	return ...
end
immediates[forever] = true

-- ( -- )
dictionary['break'] = function(...)
	-- TODO???
	return ...
end
immediates[dictionary['break']] = true

function mapstack(f, ...)
	if height(...) == 0 then return end

	return f((...)), mapstack(f, select(2, ...))
end

function eachstack(f, ...)
	if height(...) == 0 then return end

	f((...))
	return eachstack(f, select(2, ...))
end

dictionary['[]'] = fli.wrapfunc(stack.new, 0)

-- ( [x] -- [x] x )
dictionary['[]@'] = function(stk, ...)
	return stk:top(), ...
end

-- ( [x] -- x )( stk: [] )
dictionary['[]>'] = function(stk, ...)
	return stk:pop(), ...
end

-- ( x [] -- [x] )
dictionary['>[]'] = function(stk, x, ...)
	stk:push(x)
	return stk, ...
end

-- ( [*] -- [] )
dictionary['[]clear'] = function(stk, ...)
	stk:clear()
	return ...
end

-- ( t k -- t x )
dictionary['@@'] = function(k, t, ...)
	return t[k], ...
end

-- ( x t k -- t )
dictionary['!!'] = function(k, t, x, ...)
	t[k] = x
	return t, ...
end

-- Token Stream Interpreter ----------------------------------------------------

-- ( * -- * ) ( TS: tok... )
-- TODO: make this as minimal as possible, and replace with firth impl?
--! @private
local function _interpret_r(...)
	if not intptr_running or parse_pos > #tok_stream then
		if cstack.height > 0 then popparsestate() end -- may have been cleared in error handler
		return ...
	end

	if tok_stream:sub(parse_pos, parse_pos):match("%s") then
		local space = parsematch('^%s+')
		local oldline = line_num
		countlines(space)
		if line_num > oldline then debug("---Line %d---", line_num) end
	end
	local word = parse('%s')
	if not nonempty(word) then
		popparsestate()
		return ...
	end

	-- try dictionary lookup
	if defined(word) then
		if compiling then srcappend(word) end
		local found = lookup(word)
		if type(found) == "function" then
			if not compiling or immediates[found] then
				-- pass through drop because xpcall returns an boolean flag,
				-- already handled elsewhere
				return _interpret_r(drop(xpcall(found, xperrhandler, ...)))
			end
			return _interpret_r(ccall(word, ...)) -- pass `found` instead to static-link
		end

		if compiling then
			return _interpret_r(ccall(lookup, cpush(word, ...)))
		end
		return _interpret_r(found, ...)
	end

	-- try to parse it as a literal value
	local val = stringio.tonumber(word) or stringio.toboolean(word)
	if val ~= nil or word == 'nil' then
		if compiling then srcappend(word) end
		return _interpret_r(cpush(val, ...))
	end

	-- error; use xpcall, so we get the stacktrace
	xpcall(lookup_err, xperrhandler, word, true, ...)
	return ...
end

-- ( s -- * )
function runstring(src, ...)
	pushparsestate()
	tok_stream = src
	intptr_running = nonempty(src)
	line_num = 1
	parse_pos  = 1

	debug("---Line 1---")
	return _interpret_r(...)
end

local function _afterfile(success, ...)
	debug("FILE COMPLETED %sSUCCESSFULLY", success and "" or "UN")
	if not success then
		runtime_err("runfile", top(...))
	elseif compiling then
		runtime_err("runfile", "UNEXPECTED EOF WILE COMPILING")
	end

	if cstack.height >= 2 then -- could have been cleared if error
		popinputstate()
		debug("RETURNING TO COMPILING %s, %d CHARS LEFT", current_infile, #tok_stream - parse_pos)
	end

	return ...
end

-- ( path -- * )
--! Runs the specified file.
--! @param path path to file to load.
--! @param ...  firth stack.
--! @return     contents of stack after execution.
function runfile(path, ...)
	-- TODO: default/search paths?
	pushinputstate()
	stringio.input(path)
	current_infile = path
	-- TODO stream a line at a time?
	-- ...will require holding onto incomplete parse state,
	-- e.g. for matching a close paren that hasn't been read yet.
	local src = stringio.read()

	return _afterfile(pcall(runstring, src, ...))
end

--[[
local depth = 0
local prints = dictionary[".S"]
local function _postcall(...)
	depth = depth - 1
	local indentation = ("	"):rep(depth)
	-- debug("%s<==[ %s ]", indentation, prepstack(...))
	stringio.print(("🐛%s<==[ "):format(indentation))
	prints(...)
	stringio.printline("]")
	-- debug("%sCOMPILING? (%s)", indentation, compiling)
	return ...
end
for k,v in pairs(dictionary) do
	if type(v) == "function" and k ~= "quote" and k ~= "height" then
		dictionary[k] = function(...)
			debug("%sCALLING WORD: %s", ("	"):rep(depth), k)
			depth = depth + 1
			return _postcall(v(...))
		end
	end
end
--]]

cclearstate(false)
runfile "proto/core.firth"

-- Export
return {
	runstring = runstring,
	runfile = runfile,
	dictionary = dictionary
}
