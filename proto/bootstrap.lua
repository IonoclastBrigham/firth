--------------------------------------------------------------------------------
--! @file
--! @brief prototype :Firth bootstrap script.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2025 Brigham Toskin
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

-- compat defs for different versions of PUC-Rio Lua / LuaJIT
package.path = "./?/init.lua;"..package.path
bit = require "compat.bit" -- Lua@5.2 bit32; Lua@5.4 operators
loadstring = loadstring or load -- Lua@5.3+
setfenv = setfenv or require 'compat.compat_env'.setfenv  -- Lua@5.2+
unpack = unpack or table.unpack  -- Lua@5.2+
tonumber = require "compat.tonumber" -- Lua@5.2+
ipairs = require "compat.ipairs" -- Lua@5.1/JIT

-- cache common lua globals before nuking the environment
local assert, error = assert, error
local debug = debug
local getmetatable, setmetatable = getmetatable, setmetatable
local ipairs, pairs = ipairs, pairs
local loadstring = loadstring
local math = math
local os = os
local print = print
local rawget, rawset = rawget, rawset
local require = require
local setfenv = setfenv
local select, table, unpack = select, table, unpack
local tostring, tonumber = tostring, tonumber
local type = type
local pcall, xpcall = pcall, xpcall

local bit = bit
local bitand, bitor, bitxor, bitnot = bit.band, bit.bor, bit.bxor, bit.bnot

-- :Firth utility/support imports
local fli = require "firth.fli"
local stringio = require "firth.stringio"
local stack	= require "firth.stack"
local fstack   = require "firth.fstack"
require "firth.luex"

-- set up Lua global namespace as :Firth dictionary / global environment
local _lua = fli.inject({}, _G)
_lua._G, _lua.arg = nil, nil
local _G  = { Lua =  _lua }
_G.dictionary = _G
setfenv(1, _G)
setmetatable(dictionary, {
	__newindex = function(d, k, v)
		if type(k) ~= "string" then error("Invalid Name: "..tostring(k), 2) end
		rawset(d, k, v)
	end,
	__tostring = function()
		return "{dictionary...}"
	end
})

fli.wrapglobals(Lua)
fli.maplua(dictionary, Lua) -- TODO: optional/upon request?
fli.inject(dictionary, fstack)
fli.inject(dictionary, fli) -- do we want to do this ???

--! @endcond


-- global parser / interpreter / compiler state
DEBUG_LOGS = false
PRINT_ERRS = true

compiling = false
interp_running = false
input_buffer = ""
parse_pos = 1
line_num = 1

parserules = stack.new()
cstack = stack.new()
rstack = stack.new()
do
	local rmt = table.assign({}, getmetatable(rstack))
	function rmt:__tostring()
		local height = self.height
		local buf = {}
		if height == 0 then
			buf[1] = '∅'
		else
			for i = 1, height do
				local element = rawget(self, i)
				if type(element) == 'function' then
					local metadata = meta[element]
					-- TODO: debug lib to extract xt closure, if not found
					buf[i] = metadata and metadata.name or tostring(element)
				else
					buf[i] = tostring(stringio.quote(element))
				end
			end
		end

		return "[ "..table.concat(buf, ' ').." ]"
	end
	setmetatable(rstack, rmt)
end
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
			-- pass through quote before tostring; quote will quote strings,
			-- but leave e.g. numbers untouched.
			-- then we convert everything for printing.
			return tostring(quote(x)):gsub('\\\n', '\\n'):gsub('\\9', '\\t').." "
		end,
		_reverse_r(0, ...)
	)
end

local frozen_stack = {} -- for error reporting

function recover(...)
	local stk = frozen_stack
	frozen_stack = nil
	return unpack(stk)
end

function err_middleware(success, ...)
	if success then return ... end

	local errmsg = (...)
	return (function(...)
		if dictionary.PRINT_ERRS then
			stringio.output():flush()
			stringio.output(stringio.stderr())
			stringio.printline(("ERROR: %s"):format(errmsg))
			stringio.printline(("while running %s:%d"):format(input_path, line_num))
			local stackstring = '[ '..prepstack(...)..']'
			stringio.printline('stack : '..stackstring)
			stringio.printline('cstack: '..tostring(cstack))
			stringio.printline('rstack: '..tostring(rstack))
			stringio.printline(stacktrace(3))
			stringio.output():flush()
			stringio.output(stringio.stdout())
			return clear_cstate(true, errmsg, ...)
		end
	end)(recover())
	-- local die = current_infile ~= "{STDIN}"
	-- return clear_cstate(die, select(2, ...))
end

-- ( n -- s )
function stacktrace(i, ...)
	return "call"..debug.traceback("", i or 2):sub(2), ...
end

local function runtime_err(name, msg, level, ...)
	local __FIRTH_DUMPTRACE__ = true

	frozen_stack = {...}
	error(("in %s: %s"):format(name, msg), level or 2)
end
dictionary['runtime_err'] = fli.wrapfunc(runtime_err, 3, 0)

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

	-- Limit to 5 dictionary fuzzy matches but add Lua global matches
	local count = math.min(#result, 5)
	result = table.slice(result, 1, count)
	if defined("Lua."..tok) then
		table.insert(result, "Lua."..tok)
	end

	if #result == 0 then result[1] = "(NO SUGGESTIONS FOUND)" end
	return result
end

local LOOKUP_ERR_MSG = "%s is undefined%s"

-- ( n s -- 0 )
local function lookup_err(tok, throw, ...)
	local __FIRTH_DUMPTRACE__ = true -- TODO ???

	local path = input_path--:gsub("^(.-)(/?)([^/]*)$", "%1%2")
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
	local suffix = dictionary.PRINT_ERRS and "\nDid You Mean..?\n\t"..table.concat(suggestions, "\n\t") or ""
	local msg = LOOKUP_ERR_MSG:format(tok, suffix)
	if throw then
		return runtime_err(prefix, msg, 2, ...)
	elseif dictionary.PRINT_ERRS then
		STDERR:write(msg.."\n")
	end
	return ...
end
dictionary.lookup_err = fli.wrapfunc(lookup_err, 2)

local function trace(str, ...)
	if not DEBUG_LOGS then return end

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

readline = fli.wrapfunc(stringio.readline, 0, 1)
dictionary['.readline'] = fli.wrapfunc(stringio.readline, 1, 1)

strparse = fli.wrapfunc(stringio.nexttoken, 3, 2)

-- ( s -- ) ( Out: s )
dictionary['.raw'] = function(str, ...)
	assert(type(str) == "string", (".raw: %s IS NOT A STRING"):format(str))
	stringio.printstr(str)
	return ...
end

-- ( -- )
dictionary['.S'] = function(...)
	trace("PRINT STACK (height: %d):", height(...))
	stringio.printstr(prepstack(...))
	return ...
end

-- ( s -- s' )
quote = fli.wrapfunc(stringio.quote, 1)

-- ( s -- s' )
trim = fli.wrapfunc(stringio.trim, 1)

-- ( x -- n|nil )
dictionary['string>number'] = fli.wrapfunc(stringio.tonumber, 1)



-- ( s -- b )
function defined(name, ...)
	return (rawget(dictionary, name) ~= nil), ...
end

-- ( word -- x )
function find(word, ...)
	return dictionary[word], ...
end

-- ( word -- x )
function resolve(word, ...)
	-- TODO: move the rule stack loop here and call from _interpret_r
	if defined(word) then return find(word, ...) end

	local val = stringio.tonumber(word) or stringio.toboolean(word)
	if val ~= nil or word == "nil" then return val, ... end

	lookup_err(word, true, ...)
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
		elseif ch == "\\ " then
			ch = " "
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
	if parse_pos > #input_buffer then return '', ... end

	local word, endpos = stringio.nexttoken(input_buffer, delim, parse_pos)
	parse_pos  = endpos
	return word, ...
end

--! ( pattern -- tok )
function parsematch(pattern, ...)
	-- TODO: seems redundant to pcall and then assert??
	local success, word, endpos = pcall(stringio.matchtoken, input_buffer, pattern, parse_pos)
	assert(success, word)
	parse_pos = endpos
	return word, ...
end

-- ( str -- array )
function split(str, ...)
	return stringio.split(str), ...
end

-- ( n -- ) ( TS: -n )
function backtrack(n, ...)
	parse_pos = math.max(parse_pos - n, 0)
	-- trace("BACKTRACKING TO ...%q...\n                       ^", tok_stream:sub(parse_pos, parse_pos + math.min(tok_stream:find('\n', parse_pos) - 1 or #tok_stream - parse_pos, 10)))
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
function clear_cstate(die, ...)
	trace("CLEARING COMPILE STATE 📄")

	input_path = "{STDIN}"
	stringio.input(STDIN())

	input_buffer = ""
	interp_running = not die
	parse_pos = 1
	line_num = 1

	compiling = false
	compile_target = nil

	cstack:clear()

	if die then error((...), 3) end
	return ...
end

function pushinputstate(...)
	stringio.flush()

	cstack:push(setmetatable({
		input_path = input_path,
		input_file = stringio.input(),
	}, {
		__tostring = function(io) return ("I/O{ %q, %s }"):format(io.input_path, io.input_file) end
	}))

	return ...
end

function popinputstate(...)
	stringio.flush()

	local io = cstack:pop()
	stringio.input(io.input_file)
	input_path = io.input_path

	return ...
end

function pushparsestate(...)
	cstack:push(setmetatable({
		input_buffer = input_buffer,
		interp_running = interp_running,
		parse_pos = parse_pos,
		line_num = line_num,
	}, {
		__tostring = function(prs)
			return ("PRS{ %q, %s, %s, %d }"):format(prs.input_buffer:sub(10), prs.interp_running, prs.parse_pos, prs.line_num)
		end
	}))

	return ...
end

function popparsestate(...)
	local prs = cstack:pop()
	line_num = prs.line_num
	parse_pos = prs.parse_pos
	interp_running = prs.interp_running
	input_buffer = prs.input_buffer

	return ...
end

function pushcompilestate(...)
	cstack:push(setmetatable({
		compiling = compiling,
		compile_target = compile_target,
	}, {
		__tostring = function(cmp)
			return ("CMP{ %s, %s }"):format(cmp.compiling, cmp.compile_target)
		end
	}))

	return ...
end

function popcompilestate(...)
	local cmp = cstack:pop()
	compile_target = cmp.compile_target
	compiling = cmp.compiling

	return ...
end

-- ( s -- entry )
function create(name, ...)
	trace("CREATE %q", name)
	local entry = { name = name }
	setmetatable(entry, entrymt)
	-- dictionary[name] = entry
	return entry, ...
end

dictionary['compile_target.NAME'] = "name"


dictionary['compile_target.XT'] = "xt"


dictionary['compile_target.COMPILEBUF'] = "compilebuf"


dictionary['compile_target.SRCBUF'] = "srcbuf"



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

--! Creates a closure that captures `TOS` (i.e. 1 item).
--!
--! @returns      * (forwarded return from inner lambda compilation, minus xt).
--! @compiles     a call to an anonymous function that consumes `TOS`
--!               and leaves a closure that calls the original compiled
--!               lambda with th captured values of TOS on the stack.
--! @immediate
-- ( x -- * )
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

-- ( n -- )(R: * )
function jmpcont(refheight,...)
	if rstack.height > refheight then
		local __cont = rstack:pop()
		return jmpcont(refheight, __cont(...))
	end

	return ...
end

local function _thread(entry)
	local name, compilebuf = entry.name, entry.compilebuf
	trace("BUILDING %s", name)
	if #compilebuf == 0 then
		-- catch NOOP definitions
		entry.xt = function(...) return ... end
		return
	end

	-- link up thread continuations
	local __thr
	for i = #compilebuf, 1, -1 do
		local __xt = compilebuf[i]
		if getmetatable(__xt) then __xt = __xt:compile(entry) end

		if not __thr then
			__thr = __xt
		else
			local __next = __thr
			__thr = function(...)
				return __next(__xt(...))
			end
		end
	end

	-- wrap thread for stack effects (and locals??)
	entry.xt = function(...)
		local __initialheight = rstack.height
		return jmpcont(__initialheight, __thr(...))
	end
end

-- ( -- entry )
function buildfunc(...)
	_thread(compile_target)
	local  entry = compile_target
	popcompilestate()
	return entry, ...
end

-- ( entry -- )
function bindfunc(entry, ...)
	trace("ADDING %s '%s' TO DICTIONARY", entry.xt, entry.name)
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
	compile = function(self)
		if self.xt then return self.xt end

		local src = ([[
			return function(TOS, NOS, ...)
				return NOS %s TOS, ...
			end
		]]):format(self.op)
		self.xt = loadstring(src)()
		return self.xt
	end,
	exec = function(self, b, a, ...)
		local src = ([[
			return function(_, TOS, NOS, ...) return NOS %s TOS, ... end
		]]):format(self.op)
		self.exec = loadstring(src)()
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
dictionary['not'] = function(b, ...)
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
		trace("CCALL: COMPILING CALL TO %s", quote(func))
		return cappend(xt, ...)
	else
		trace("CCALL: executing %s", func)
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
local function cbeginblock(name, breakable, completion)
	compile(create(name)) -- compile pushes prev compile state
	cstack:push(completion)
end
dictionary['cbeginblock'] = fli.wrapfunc(cbeginblock, 3, 0)

function cendblock(...)
	local completion = cstack:pop()
	local built = buildfunc()
	local do_call, thread = completion(built.xt) -- pops prev compile state
	if do_call then
		return ccall(thread, ...)
	else
		return thread, ...
	end
end

-- ( cond -- )
dictionary['if'] = function(...)
	cbeginblock("[[IF]]", false, function(thenthread)
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
	local then_completion = cstack:pop() -- drop basic if-then completion
	assert(type(then_completion) == "function", "Compiler error: "..type(then_completion).." on cstack instead of function")
	local thenthread = buildfunc().xt

	-- replacement completion for end
	cbeginblock("[[ELSE]]", false, function(elsethread)
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

function execif(thenthread, cond, ...)
	if cond then
		return thenthread(...)
	else
		return ...
	end
end
dictionary['?exec'] = execif -- NOT immediate

dictionary['?continue'] = function(...)
	local loopcompletion = cstack:pop()
	local prefix = buildfunc().xt

	-- replacement completion for endloop
	cbeginblock("[[CONTINUE]]", true, function(suffix)
		return loopcompletion(function(...)
			-- negate because we want to execute the suffix if the prefix is not true
			return execif(suffix, dictionary['not'](prefix(...)))
		end)
	end)
	return ...
end
immediates[dictionary['?continue']] = true

-- ( nstart nlimit -- )
dictionary['for'] = function(...)
	cbeginblock("[[FOR]]", true, function(forthread)
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

-- ( iterable -- ) (EX: x --)
function each(...)
	cbeginblock("[[EACH]]", true, function(eachthread)
		return true, function(iterable, ...)
			-- TODO: support strings and iterator xts on TOS
			-- TODO: function spairs(str) return function(str, idx) local c = str:sub(idx+1, idx+1); if  #c == 0 then return nil, nil else return idx+1, c end end, str, 0 end
			local newitr = getmetatable(iterable) and getmetatable(iterable).__ipairs
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
				return _each_r(eachthread(val, ...))
			end
			return _each_r(...)
		end
	end)
	return ...
end
immediates[each] = true

-- ( iterable -- ) (EX: x --)
function eachi(...)
	cbeginblock("[[EACHI]]", true, function(eachthread)
		return true, function(iterable, ...)
			-- TODO: support strings and iterator xts on TOS
			-- TODO: function spairs(str) return function(str, idx) local c = str:sub(idx+1, idx+1); if  #c == 0 then return nil, nil else return idx+1, c end end, str, 0 end
			local newitr = getmetatable(iterable) and getmetatable(iterable).__ipairs
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
immediates[eachi] = true

-- ( cond -- )
dictionary['while'] = function(...)
	-- TODO: a coopt the block thread to allow a `WHILE cond DO xxx END` form..?
	cbeginblock("[[WHILE]]", true, function(whilethread)
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
	cbeginblock("[[LOOPS]]", true, function(loopsthread)
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
	cbeginblock("[[FOREVER]]", true, function(foreverthread)
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

-- ( *x -- *x' )
function mapstack(f, ...)
	if height(...) == 0 then return end

	return f((...)), mapstack(f, select(2, ...))
end

-- ( * -- )
function eachstack(f, ...)
	if height(...) == 0 then return end

	f((...))
	return eachstack(f, select(2, ...))
end

dictionary['[]'] = fli.wrapfunc(stack.new, 0)

-- ( -- x)(R: x -- )
-- R-from is a prim to avoid mucking with stack ops as they happen.
-- ⚠️ DO NOT DELETE THIS FUNCTION
dictionary['R>'] = function(...)
	return rstack:pop(), ...
end

-- ( x -- )(R: -- x )
-- to-R is a prim to avoid mucking with stack ops as they happen.
-- ⚠️ DO NOT DELETE THIS FUNCTION
dictionary['>R'] = function(tos, ...)
	rstack:push(tos)
	return ...
end

-- ( t k -- t x )
-- This is used very early in the bootstrapping process to
-- implement `immediate`.
dictionary['@@'] = function(k, t, ...)
	return t[k], ...
end

-- ( x t k -- t )
-- This is used very early in the bootstrapping process to
-- implement `immediate`.
dictionary['!!'] = function(k, t, x, ...)
	trace("%s[%s] = %s", t, quote(k), quote(x))
	t[k] = x
	return t, ...
end

-- Token Stream Interpreter ----------------------------------------------------

-- fallback rule; error
parserules:push(function(word, ...)
	lookup_err(word, true, ...)
	-- NO RETURN
end)

-- try to parse it as a literal value
parserules:push(function(word, ...)
	return word == "nil" and "literal", nil, ...
end)
parserules:push(function(word, ...)
	local val = stringio.toboolean(word)
	if val ~= nil then trace("PARSED BOOLEAN %s", val) end
	return val ~= nil and "literal", val, ...
end)
parserules:push(function(word, ...)
	local val = stringio.tonumber(word)
	if val ~= nil then trace("PARSED NUMBER %s", val) end
	return val ~= nil and "literal", val, ...
end)

-- dictionary lookup rule
parserules:push(function(word, ...)
	local found = find(word)
	if found ~= nil then trace("FOUND %q", word) end
	return found ~= nil, found, ...
end)

-- ( * -- * ) ( TS: tok... )
-- TODO: make this as minimal as possible, and replace with :Firth impl?
--! @private
local function _interpret_r(...)
	-- bail if we're done
	if not interp_running or parse_pos > #input_buffer then
		if cstack.height > 0 then popparsestate() end -- may have been cleared in error handler
		return ...
	end

	-- count any leading newlines
	if input_buffer[parse_pos]:match("%s") then
		local space = parsematch('^%s+')
		local oldline = line_num
		countlines(space)
		if line_num > oldline then trace("--- %s:%d ---", input_path, line_num) end
	end

	-- parse out the next word
	local word = parse('%s')
	if not nonempty(word) then
		-- EOF; bail
		popparsestate()
		return ...
	end
	if compiling then srcappend(word) end

	-- loop through parse rules here
	trace("RESOLVING INPUT WORD '%s'", word)
	local success, found
	for _, rule in ipairs(parserules) do
		success, found = rule(word)
		if success then break end
	end

	-- TODO: decompose these into a stack of COMPILE rules? --

	-- interpret/compile?
	if type(found) == "function" then
		if not compiling or immediates[found] then
			trace("EXECUTING %s", word)
			return _interpret_r(err_middleware(pcall(found, ...)))
		else
			trace("COMPILING CALL TO %s", word)
			return _interpret_r(ccall(found, ...)) -- pass `word` instead to dynamic-link
		end
	end

	-- push
	if success == "literal" then
		trace("%sPUSH: LITERAL %s", compiling and "COMPILING " or "", found)
		return _interpret_r(cpush(found, ...))
	elseif compiling then
		-- we're referencing a global var, so we want updates to its value reflected at runtime.
		trace("COMPILING PUSH: {dictionary...}[%q]", word)
		return _interpret_r(ccall(find, cpush(word, ...)))
	end
	trace("PUSH: %s (%s)", word, quote(found))
	return _interpret_r(found, ...)
end

-- ( s -- * )
function runstring(src, ...)
	trace("RUNSTRING WITH INCOMING STACK HEIGHT: %d", height(...))
	pushparsestate()
	input_buffer = src
	interp_running = nonempty(src)
	line_num = 1
	parse_pos  = 1

	trace("--- %s:1 ---", input_path)
	return _interpret_r(...)
end

local function _afterfile(path, success, ...)
	trace("FILE COMPLETED: %sSUCCESSFULLY", success and "👍 " or "💀 UN")
	-- if not success then
	-- 	runtime_err(("`%q runfile`"):format(path), "ERROR WHILE RUNNING FILE", 0)
	-- elseif compiling then
	-- 	runtime_err(("`%q runfile`"):format(path), "UNEXPECTED EOF WILE COMPILING", 0)
	-- end

	if cstack.height > 0 then -- could have been cleared if error
		popinputstate()
		trace("RETURNING TO COMPILING %s, %d CHARS LEFT", input_path, #input_buffer - parse_pos)
	end

	return success, ...
end

-- ( path -- * )
--! Runs the specified file.
--! @param path path to file to load.
--! @param ...  :Firth stack.
--! @return     contents of stack after execution.
function runfile(path, ...)
	trace("RUNFILE %q", path)
	local success, src
	
	-- TODO: default/search paths?
	pushinputstate()
	input_path = path
	success = pcall(stringio.input, path)
	if not success then return _afterfile(path, false, "Could not open file", ...) end

	-- TODO: stream a line at a time?
	-- ...will require holding onto incomplete parse state,
	-- e.g. for matching a close paren that hasn't been read yet.
	-- On the other hand, file would have to be multiple megabytes to matter. 🤷‍♀️
	success, src = pcall(stringio.read)
	if not success then return _afterfile(path, false, "Could not read file", ...) end

	return _afterfile(path, pcall(runstring, src, ...))
end

--[[
local depth = 0
local prints = dictionary['.S']


local function _postcall(...)
	depth = depth - 1
	local indentation = ("	"):rep(depth)
	-- debug("%s<==[ %s ]", indentation, prepstack(...))
	stringio.print(("🐛%s<==[ "):format(indentation))
	prints(...)
	stringio.printline(']")
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

-- prepare lua prims for Export
for k, v in pairs(dictionary) do
	if type(v) == 'function' then
		meta[v] = { name = k, xt = v }
	end
end

-- Prepare the Export
local firth = {
	runstring = runstring,
	runfile = runfile,
	dictionary = dictionary,
	loaded = false,
}

clear_cstate(false)
firth.loaded = runfile "proto/core.firth"
PRINT_ERRS = false -- default error printing to disabled after core is loaded

return setmetatable(firth, {
	__call = function(f, str, ...)
		if not f.loaded then error("UNINITIALIZED", 2) end
		return pcall(runstring, str, ...)
	end,
	__index = firth
})
