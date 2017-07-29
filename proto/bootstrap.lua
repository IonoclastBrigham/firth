-- prototype :Firth bootstrap script


--! @cond

-- cache common lua globals before nuking the environment
local error = error
local ipairs, pairs = ipairs, pairs
local print = print
local rawget = rawget
local setfenv = setfenv or require 'compat.compat_env'.setfenv
local setmetatable, table = setmetatable, table
local tostring = tostring
local type = type
local xpcall = xpcall

-- firth imports
local stringio = require "firth.stringio"
local stack = require "firth.fstack"

--! @endcond


-- set up dictionary / global environment
local _lua = _G
_lua._G = nil
local _G  = { Lua = _lua }
_G._G = _G
setfenv(1, _G)


-- ( s -- b )
function defined(name, ...)
	return rawget(_G, name) ~= nil, ...
end


-- global parser / interpreter / compiler state
-- TODO: put some thought into naming, as they are part of the de facto API
intr_running = false
compiling = false
current_infile = "stdin"
tok_stream = ""
line_num = 1
parse_pos = 1

immediate = {} -- immediate[func] = true
src = {} -- src[func] = src_str (lua src? firth? both?)

frozen_stack = {} -- for error reporting

-- ( -- )
function clear_compilestate(...)
	intr_running = false
	compiling = false
	current_infile = "stdin"
	stringio.input(stringio.stdin())
	tok_stream = ""
	line_num = 1
	parse_pos = 1
--	self.target = nil
--	self.cstack:clear()

	return ...
end

-- ( s1 -- s2 )
function parse(delim, ...)
	if parse_pos > #tok_stream then
		return '', ...
	end
	local token, endpos = stringio.nexttoken(tok_stream, delim, parse_pos)
	parse_pos  = endpos
	return token, ...
end

-- ( s? -- b )
function nonempty(str, ...)
	return type(str) == "string" and #str > 0, ...
end

-- ( -- )
_G['\n'] = function(...)
	line_num = line_num + 1
	return ...
end

-- ( x -- ) ( $1: sx )
_G['.'] = function(x, ...)
	stringio.print(tostring(x), ' ')
	return ...
end

-- Token Stream Interpreter ----------------------------------------------------

-- ( * -- * ) ( TS: tok... )
-- TODO: Should we just consider this an implementation detail of `interpret`..?
-- TODO: Or should we make it global, and therefore pluggable/extensible?
--! @private
local function interpret_r(...)
	if parse_pos > #tok_stream then return ... end
	local token = parse(' \t')
	intr_running = nonempty(token)
	if not intr_running then return ... end

	-- try dictionary lookup
	if defined(token) then
		local found = _G[token]
		if type(found) == "function" then
			-- TODO: actually, do I want to call it? I think I do...
			return interpret_r(stack.drop(xpcall(found, xperrhandler, ...)))
		else
			return interpret_r(found, ...)
		end
	else
		-- try to parse it as a number or boolean
		local val = stringio.tonumber(token) or stringio.toboolean(token)
		if val ~= nil then
			return interpret_r(val, ...)
		else
			-- error; use xpcall, so we get the stacktrace
			xpcall(lookup_err, xperrhandler, token, line_num, ...)
			return ...
		end
	end
end

-- ( s -- * )
function interpret(src, ...)
	-- init interpreter state before jumping to recursive interpret routine
	intr_running = nonempty(src)
	tok_stream = src
	parse_pos  = 1
	line_num = 1

	return interpret_r(...)
end

-- Error Handling --------------------------------------------------------------

function xperrhandler(msg)
	stringio.printline(("ERROR: %s"):format(msg))
	local stackstring = 'stack : ['..table.concat(frozen_stack, ', ')..']'
	stringio.printline((stackstring:gsub('\n', '\\n')))
--	stringio.print 'cstack: '
--	stringio.printline(tostring(cstack))
--	stringio.printline(stacktrace())
end

-- (n s1 s2 -- 0 )
function runtime_err(name, msg, level, ...)
	local __FIRTH_DUMPTRACE__ = true

	clear_compilestate()
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

-- ( n s -- 0 )
function lookup_err(tok, num, ...)
	local __FIRTH_DUMPTRACE__ = true

	num = num or line_num
	local path = current_infile--:gsub("^(.-)(/?)([^/]*)$", "%1%2")
	if not path or #path == 0 then path = "./" end
	local prefix = path..':'..num
	local buckets = {}
	for k,v in pairs(_G) do
		for i = 1, #tok do
			buckets[i] = buckets[i] or {}
			if i > #k then break end
			if tok:sub(i,i) == k:sub(i,i) then
				table.insert(buckets[i], k)--..(immediate[v] and " (immediate)" or ""))
				break
			end
		end
	end
	local suffix = "Did You Mean..?\n\t"..table.concat(sortmatches(buckets, tok), "\n\t")
	return runtime_err(prefix, "UNKNOWN WORD '"..tok.."'\n"..suffix, 2, ...)
end


-- Export
return interpret
