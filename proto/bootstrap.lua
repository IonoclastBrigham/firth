--------------------------------------------------------------------------------
--! @file fstack.lua
--! @brief prototype :Firth bootstrap script.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2021 Brigham Toskin
--!
--! <p>This file is part of the :Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


--! @cond

-- cache common lua globals before nuking the environment
local assert, error = assert, error
local getmetatable, setmetatable = getmetatable, setmetatable
local ipairs, pairs = ipairs, pairs
local loadstring = loadstring
local math = math
local os = os
local print = print
local rawget = rawget
local require = require
local setfenv = setfenv or require 'compat.compat_env'.setfenv
local select, table, unpack = select, table, unpack or table.unpack
local tostring = tostring
local type = type
local pcall, xpcall = pcall, xpcall

local bit = bit or bit32
local bitand, bitor, bitxor, bitnot = bit.band, bit.bor, bit.bxor, bit.bnot

-- firth imports
local stringio = require "firth.stringio"
local stack    = require "firth.stack"
local fstack   = require "firth.fstack"

-- set up Lua global namespace as firth dictionary / global environment
local _lua = _G
_lua._G = nil
local _G  = { Lua = _lua }
for k, v in pairs(fstack) do _G[k] = v end
_G.dictionary = _G
-- setmetatable(_G, { __index = _G })
setmetatable(_G, getmetatable(_lua))
setfenv(1, _G)
-- TODO: metatable inheritence mechanisms for vocabs
-- (maybe not in bootstrap file though?)

--! @endcond


-- global parser / interpreter / compiler state
-- TODO: put some thought into naming, as they are part of the de facto API
intptr_running = false
current_infile = "stdin"
tok_stream = ""
line_num = 1
parse_pos = 1
next_tmp = 1

compiling = false
compile_target = nil
cstack = stack.new()

immediates = {} -- immediates[func] = true
src = {} -- src[func] = src_str (lua src? firth? both?)

local frozen_stack = {} -- for error reporting

--! @private
local entrymt = {
	__tostring = function(t)
		return ("{%s}"):format(t.name)
	end
}
entrymt.__index = entrymt

-- Error Handling --------------------------------------------------------------

function xperrhandler(msg)
	stringio.printline(("ERROR: %s"):format(msg))
	stringio.printline(("while running %s:%d"):format(current_infile, line_num))
	local stackstring = '[ '..prepstack(unpack(frozen_stack))..' ]'
	stringio.printline('stack : '..stackstring)
	stringio.printline('cstack: '..tostring(cstack))
	-- stringio.printline('dict  :')
	-- for k, _ in pairs(dictionary) do stringio.printline("    "..k) end
	-- stringio.printline(stacktrace())

	cclearstate()
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
local function lookup_err(tok, num, ...)
	local __FIRTH_DUMPTRACE__ = true -- TODO ???

	num = num or line_num
	local path = current_infile--:gsub("^(.-)(/?)([^/]*)$", "%1%2")
	if not path or #path == 0 then path = "./" end
	local prefix = path..':'..num
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
	local suffix = "Did You Mean..?\n\t"..table.concat(sortmatches(buckets, tok), "\n\t")
	return runtime_err(prefix, LOOKUP_ERR_MSG:format(tok, suffix), 2, ...)
end

debuglogs = false
local function debug(str, ...)
	if not debuglogs then return end

	str = "🐛 "..str
	if select("#", ...) > 0 then str = str:format(...) end
	stringio.printline(str)
end


-- core primitives -------------------------------------------------------------

local function mapstack(f, ...)
	if height(...) == 0 then return end

	return f((...)), mapstack(f, select(2, ...))
end

function eachstack(f, ...)
	if height(...) == 0 then return end

	f((...))
	return eachstack(f, select(2, ...))
end

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

-- ( -- )
function bye(...)
	printstack(...)
	stringio.printline "Goodbye 🖤"
	os.exit(0)
end

-- ( s -- ) ( Out: s )
dictionary['.raw'] = function(str, ...)
	assert(type(str) == "string", "NOT A STRING")
	stringio.print(str)
	return ...
end

-- ( x -- ) ( Out: s(x) )
local dot_fmt = "%s "
dictionary['.'] = function(x, ...)
	return dictionary['.raw'](dot_fmt:format(x), ...)
end

-- ( * -- )
dictionary[".S"] = function(...)
	return stringio.print(prepstack(...))
end

-- ( s -- s' )
function quote(str, ...)
	if type(str) == "string" then
		str = ("%q"):format(str)
	end
	return str, ...
end

-- ( s -- s' )
function trim(str, ...)
	return stringio.trim(str), ...
end

-- ( s -- b )
function defined(name, ...)
	return (rawget(dictionary, name) ~= nil), ...
end

-- ( word -- x )
function lookup(word, ...)
	return dictionary[word], ...
end

function resolve(word, ...)
	if defined(word) then
		return lookup(word, ...)
	else
		local val = stringio.tonumber(word) or stringio.toboolean(val)
		if val == nil then
			-- error; use xpcall, so we get the stacktrace
			xpcall(lookup_err, xperrhandler, word, line_num, ...)
		else
			return val, ...
		end
	end
end

dictionary["not"] = function(b, ...)
	return not b, ...
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
immediates['char'] = true

-- ( n*x s1 -- s2)
function fmt(str, ...)
	str = str:gsub("\\t", "\t"):gsub("\\n", "\n"):gsub('\\"', '"')
	local _, count = str:gsub("%%[^%%]", "")
	return str:format(...), select(count + 1, ...)
end

-- ( -- )
function cclearstate(...)
	debug("CLEARING COMPILE STATE!!!!!!!")
	intptr_running = false
	current_infile = "stdin"
	stringio.input(stringio.stdin())
	tok_stream = ""
	line_num = 1
	parse_pos = 1
	next_tmp = 1

	compiling = false
	compile_target = nil
	cstack = stack.new()

	return ...
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


local function newcompilebuf()
-- 	return {
-- [[local __FIRTH_WORD_NAME__ = %q
-- --%%s
-- --%%s
-- return function(...) ]]
-- 	}
	return {}
end



-- ( s -- entry )
function create(name, ...)
	debug("CREATE %q", name)
	local entry = {
		-- TODO?
		name = name --, compilebuf = newcompilebuf(),
		--calls = { nextidx = 1 }, calledby = {}, upvals = { nextidx = 1 }
	}
	setmetatable(entry, entrymt)
	-- dictionary[name] = entry
	return entry, ...
end

-- ( entry -- )
function compile(newtarget, ...)
	assert(getmetatable(newtarget) == entrymt, "INVALID TARGET ")

	-- print("COMPILING: "..newtarget.name)
	newtarget.compilebuf = newcompilebuf()
	if compile_target then cstack:push(compile_target) end
	compile_target = newtarget
	compiling = true
	return ...
end

-- ( -- ) ;immed
function interpret(...)
	compiling = false
	return ...
end
immediates['interpret'] = true

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
	if cstack.height > 0 and getmetatable(cstack:top()) == entrymt then
		compile_target = cstack:pop()
	else
		compile_target = nil
	end

	local name, compilebuf = entry.name, entry.compilebuf
	debug("BUILDING %s", name)
	entry.xt = (#compilebuf > 0) and _thread_r(unpack(compilebuf)) or function(...) return ... end

	return entry, ...
end

-- ( entry -- )
function bindfunc(entry, ...)
	dictionary[entry.name] = entry.xt
	return ...
end

-- ( xt * -- * )
function exectoken(xt, ...)
	return xt(...)
end

-- ( x * -- * )
dictionary["exectoken?"] = function(xt, ...)
	if type(xt) == "function" then return xt(...) end
	return xt, ...
end

-- ( entry -- )
function immediate(entry, ...)
	immediates[entry.name] = true
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
			-- print(...)
			-- skip `self`
			local TOS = select(2, ...)
			local NOS = select(3, ...)
			return NOS %s TOS, select(4, ...)
		]]):format(self.op)
		debug("COMPILING BINOP FUNC: '%s'", src)
		self.exec = loadstring(src)
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
		cappend(xt, ...)
	else
		xt(...)
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

-- this is not meant to be a prim word available to firth code.
-- is there a reasonable usecase for doing so?
local function cbeginblock()
	-- TODO: when entering a block, new tmp to capture output stack?
	cstack:push(compiling)
	cstack:push(compile_target)
	if not compiling then
		compile(create("[INTERP_BUF]"))
	else
		-- TODO: same thing, different name?
	end
end

-- this is not meant to be a prim word available to firth code.
-- is there a reasonable usecase for doing so?
local function cendblock()
	compile_target = cstack:pop()
	compiling = cstack:pop()
	if not compiling then
		exectoken(buildfunc().xt)
	else
		-- TODO: cappend closure for correct block type
	end
end

-- ( cond -- )
dictionary['if'] = function(...)
	cbeginblock()
	local cond = cnewtmp('top(...)') -- FIXME: how to manage stack here??
	cappend(("if %s then"):format(cond))
	return ...
end

-- ( -- )
dictionary['else'] = function(...)
	cappend('else')
	return ...
end

-- ( -- )
dictionary['end'] = function(...)
	cendblock()
	return ...
end

-- ( first last -- )
dictionary['for'] = function(...)
	cbeginblock()
	local i = cnewtmp()
	-- TODO: I think these need to come in as named params of the lua function?
	local last, first = compiler:poptmp(), compiler:poptmp()
	cappend(("for %s = %s, %s do"):format(i, first, last))
	cpush(i)
	return ...
end

-- ( cond -- )
dictionary['while'] = function(...)
	cbeginblock()
	cappend("while(stack:pop()) do") -- FIXME: how to manage stack here??
	return ...
end

-- ( -- )
dictionary['break'] = function(...)
	cappend('break')
	return ...
end

-- ( -- )
dictionary['do'] = function(...)
	cbeginblock()
	cappend('do')
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

local function popparsestate()
	if cstack.height >= 4 then
		intptr_running = cstack:pop()
		parse_pos = cstack:pop()
		line_num = cstack:pop()
		tok_stream = cstack:pop()
	end
end

-- ( * -- * ) ( TS: tok... )
-- TODO: make this as minimal as possible, and replace with firth impl?
--! @private
local function _interpret_r(...)
	if not intptr_running or parse_pos > #tok_stream then
		popparsestate()
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
		local found = lookup(word)
		if type(found) == "function" then
			if not compiling or immediates[word] then
				-- pass through drop because xpcall returns an error flag, already handled elsewhere
				return _interpret_r(drop(xpcall(found, xperrhandler, ...)))
			else
				return _interpret_r(ccall(found, ...))
			end
		else
			if compiling then
				return _interpret_r(ccall(lookup, cpush(word, ...)))
			else
				return _interpret_r(found, ...)
			end
		end
	end

	-- try to parse it as a literal value
	local val = stringio.tonumber(word) or stringio.toboolean(word)
	if val ~= nil then
		return _interpret_r(cpush(val, ...))
	else
		if word == 'nil' then
			return _interpret_r(cpush(nil, ...))
		else
			-- error; use xpcall, so we get the stacktrace
			xpcall(lookup_err, xperrhandler, word, line_num, ...)
			return ...
		end
	end
end

-- ( s -- * )
function runstring(src, ...)
	cstack:push(tok_stream)
	cstack:push(line_num)
	cstack:push(parse_pos)
	cstack:push(intptr_running)

	tok_stream = src
	line_num = 1
	parse_pos  = 1
	intptr_running = nonempty(src)

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
		current_infile = cstack:pop()
		stringio.input(cstack:pop())
		debug("RETURNING TO COMPILING %s, %d CHARS LEFT", current_infile, #tok_stream - parse_pos)
	end

	return ...
end

-- ( path -- * )
function runfile(path, ...)
	-- TODO: default/search paths?

	cstack:push(stringio.input())
	cstack:push(current_infile)

	stringio.input(path)
	current_infile = path
	-- TODO stream a line at a time?
	-- ...will require holding onto incomplete parse state,
	-- e.g. matching a close paren.
	local src = stringio.read()

	return _afterfile(pcall(runstring, src, ...))
end

--[[
local depth = 0
local prints = dictionary[".S"]
local function _postcall(...)
	depth = depth - 1
	local indentation = ("    "):rep(depth)
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
			debug("%sCALLING WORD: %s", ("    "):rep(depth), k)
			depth = depth + 1
			return _postcall(v(...))
		end
	end
end
--]]

local skipcore = select(2, ...)
if not skipcore then runfile "proto/core.firth" end

-- Export
return {
	runstring = runstring,
	runfile = runfile,
	dictionary = dictionary
}
