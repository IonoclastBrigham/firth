--------------------------------------------------------------------------------
--! @file
--! @brief Text io and manipulation routines for :Firth language.
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
local string = require 'string'
local table = require 'table'
local io = require 'io'

local stdout = io.stdout

local ipairs = ipairs
local print = print
local tonumber = tonumber
local type = type


local function shift(tbl)
	return table.remove(tbl, 1)
end

local function pop(tbl)
	return table.remove(tbl)
end

local stringio = {
	__FIRTH_INTERNAL__ = "<stringio>" -- used for stacktraces
}
--! @endcond


--! Creates a Lua-style iterator to loop over tokens in string.
--! Tokens are any consecutive printable chars broken up by white space.
--! @param str the string of tokens to iterate over.
--! @param delim the string or pattern that delimits the tokens.
--! @return an iterator function suitable for a for loop.
--! @see #split()
function stringio.tokens(str, delim)
	delim = delim or "([^%s]+)"
	return string.gmatch(str, delim)
end

--! Splits a string into an array, tokenized on whitespace.
--! Tokens are any consecutive printable chars broken up by white space.
--! @param str   the string of tokens to split.
--! @param delim the string or pattern that delimits the tokens.
--! @return an array of tokenized substrings.
--! @see #tokens()
function stringio.split(str, delim)
	delim = delim or "([^%s]+)"
	local result = {}
	for word in stringio.tokens(str, delim) do
		table.insert(result, word)
	end
	return result
end

--! Finds a substring at or after start pos, surrounded by 0 or more delims.
--!
--! This function calculates the next token, delimited as specified, from
--! the start position.
--!
--! @param str the string to tokenize
--! @param delim the delimiter pattern to tokenize with,
--! 	defaults to '%s' (whitespace)
--! @param start the starting char position to start searching, defaults to 1
--! @return the token, 1 past the end index of the token in the input string
--! @see #matchtoken()
function stringio.nexttoken(str, delim, start)
	-- here %s is an alias for any whitespace
	delim = delim or "%s"
	start = start or 1

	-- here %s is a string formatter as in C
	local pattern = string.format("^([%s]*)([^%s]+)([%s]?)", delim, delim, delim)
	local discard1, token, discard2 = str:match(pattern, start)

	if token == nil then return "", math.huge end
	return token, start + #discard1 + #token
end

--! Finds the next matching token from the front of a string.
--!
--! This function matches the first occurrence of specified pattern. This
--! function differs from #nexttoken() in that it finds a positive match, rather
--! than the first thing it finds that doesn't match a delimiter pattern.
--!
--! @param str the string to tokenize
--! @param pattern the pattern to match against
--! @param start the starting char position to start searching, defaults to 1
--! @return the token, 1 past the end index of the token in the input string
--! @see #nexttoken()
function stringio.matchtoken(str, pattern, start)
	start = start or 1
	local searchregion = str:sub(start)
	local tstart, tend, token = searchregion:find(pattern)
	if not token then token = searchregion:sub(tstart, tend) end
	return token, start + tend
end

--! @param str a string to trim whitespace from.
--! @return the input string with leading and trailing whitespace removed.
function stringio.trim(str)
	return string.match(str,'^()%s*$') and '' or string.match(str,'^%s*(.*%S)')
end

--! Tries to convert a string into a number.
--!
-- <p>This function attempts to parse a string as a numeric value, and convert
--! it to the corresponding number. Surrounding whitespace is ignored, but any
--! other non-contiguous or invalid characters mean this string is not a number.
--! </p>
--!
--! <p>If the argument is not of type string or number, it will attempt to first
--! convert it to a string, and then convert that to a number. If that fails,
--! the result is \c nil.</p>
--!
--! <p>Some examples of valid numeric strings:</p>
--! <ul>
--! <li> \c "1"
--! <li> \c "1."
--! <li> \c ".1"
--! <li> \c "1.0"
--! <li> \c "  3.14159"
--! <li> \c " -1.48532e-12 "
--! <li> \c "0xff" -- hex
--! <li> \c "0777" -- octal
--! <li> \c "0b10" -- binary
--! </ul>
--!
--! <p>Some examples of <i>invalid</i> numeric strings:</p>
--! <ul>
--! <li> \c "1!"
--! <li> \c "1 2"
--! <li> \c "3.14159 = PI"
--! <li> \c "zero"
--! </ul>
--!
--! @param val a token string to convert.
--! @return the parsed numeric value of \c val, or \c nil.
function stringio.tonumber(val)
	if type(val) == "string" then
		val = stringio.trim(val)
		local radix
		if val:match("^0[0-7]+$") then
			radix = 8
		else
			local bin = val:match("^0b([01]+)$")
			if bin then
				radix = 2
				val = bin
			end
		end
		-- hex strings prefixed with '0x' will be recognized
		return tonumber(val, radix)
	end
	if type(val) == "number" then return val end
	return tonumber(tostring(val))
end

--! Tries to convert a string to a boolean.
--!
-- <p>This function attempts to parse a string as a boolean value, and convert
--! it to the corresponding boolean. Surrounding whitespace is ignored, and the
--! conversion is case-insensitive, but any other non-contiguous or invalid
--! characters mean this string is not a boolean.</p>
--!
--! <p>If the argument is not of type string, it will attempt to first convert
--! it to a string, and then convert that to a boolean. If that fails, the
--! result is \c nil.</p>
--!
--! <p>Some examples of convertible input strings:</p>
--! <ul>
--! <li> \c "true"
--! <li> \c "false"
--! <li> \c "  TRUe\t"
--! </ul>
--!
--! <p>Some examples of <i>invalid</i> boolean strings:</p>
--! <ul>
--! <li> \c "True!"    -- No!
--! <li> \c "~false"   -- Bad!
--! <li> \c "not true" -- You can't do that!
--! <li> \c "nil"      -- What even are you doing here?
--! </ul>
--!
--! @param val a token string to convert.
--! @return the parsed boolean value of \c val, or \c nil.
function stringio.toboolean(val)
	if type(val) ~= 'string' then
		return stringio.toboolean(tostring(val))
	end


	val = stringio.trim(val):lower()
	if val == 'true' then
		return true
	elseif val == 'false' then
		return false
	else
		return nil
	end
end

-- file i/o stuff --

function stringio.stdin()
	return io.stidin
end

function stringio.input(infile)
	if type(infile) == "string" and #infile > 0 then
		return io.input(infile)
	elseif type(infile) == "userdata" and infile.read then
		return io.input(infile)
	elseif infile == nil then
		return io.input() -- return current input file
	else
		error("stringio.input() - INVALID ARGUMENT: "..tostring(infile))
	end
end

function stringio.read(file)
	file = file or stringio.input()
	return file:read("*all")
end

--! Reads a single line from file.
--! Reads text from file up to the first end-of-line char it finds.
--! The newline, if encountered, is discarded.
--! @param file descriptor object to read from. If omitted or \c nil,
--! 		uses the current input file.
--! @return a string containing the next line read from \c file, or \c nil
--! 		if it encounters EOF.
function stringio.readline(file)
	file = file or stringio.input()
	return file:read("*line")
end

function stringio.lines(file)
	file = file or stringio.input()
	return file:lines()
end

--! Prints its arguments to its output.
--! The behavior of this function can be modified depending on the first
--! argument that is passed in.
--! @param ... a list of arguments to print. If the first argument is:<ul>
--! 		<li>a function, it is called, and the returned value is used as
--!				the separator to concatenate the items of the list;
--! 		<li>a file descriptor or file-like object, it is treated as the
--! 			output file, and printing is carried out by calling its
--! 			\c write() method;
--! 		<li>anything else, it is printed as a normal value, along with
--! 			all the other arguments.
--! 	</ul>
--! @see #printline()
function stringio.print(...)
	if select('#', ...) == 0 then
		return
	end

	local arg1 = (...)
	local out
	if type(arg1) == 'function' then
		out = stdout
		out:write(table.concat(args, arg1()))
	else
		local mt = getmetatable(arg1)
		if mt and type(mt.write) == 'function' then
			out = arg1
			out:write(unpack(args))
		else
			out = stdout
			out:write(...)
		end
	end
	out:flush()
end

--! Prints its arguments to its output, with a newline appended.
--! The behavior of this function is identical to #print(), except that a
--! newline char/sequence appropriate for the host platform is appended to
--! the output stream.
--! @param ... a list of arguments to print. Please see the documentation
--! 		for the paramaters of #print(), for details.
--! @see #print()
function stringio.printline(...)
	local args = {...}
	if #args > 0 then
		stringio.print(...)
	end
	stringio.print('\n')
end

--! @private
local function getquotespec(val)
	return (type(val) == "string") and "%q" or "%s"
end

function table.concathash(t, sep)
	sep = sep or ' '
	local kvs = {}
	for k,v in pairs(t) do
		local fmt = getquotespec(k)..' = '..getquotespec(v)
		kvs[#kvs+1] = string.format(fmt, tostring(k), tostring(v))
	end
	return table.concat(kvs, sep)
end

return stringio
