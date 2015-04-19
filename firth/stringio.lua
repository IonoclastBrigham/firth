--------------------------------------------------------------------------------
--! @file stringio.lua
--! @brief Text io and manipulation routines for Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015 Brigham Toskin
--! 
--! <p>This file is part of the Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--------------------------------------------------------------------------------


--! @cond
local string = require 'string'
local table = require 'table'
local io = require 'io'

local stdout = io.stdout

local ipairs = ipairs
local print = print


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
--! @return an iterator function suitable for a for loop.
--! @see #split()
function stringio.tokens(str)
	return string.gmatch(str, "([^%s]+)")
end

--! Splits a string into an array, tokenized on whitespace.
--! Tokens are any consecutive printable chars broken up by white space.
--! @param str the string of tokens to split.
--! @return an array of tokenized substrings.
--! @see #tokens()
function stringio.split(str)
	local result = {}
	for word in stringio.tokens(str) do
		table.insert(result, word)
	end
	return result
end

--! Chops off the next token from the front of a string.
--! This function calculates the the next token, delimited as specified, from
--! the start of the string, followed by the substring that follows the
--! delimiter string.
--! @param str the string to tokenize
--! @param delim the delimiter pattern to tokenize with,
--! 	defaults to '%s' (whitespace).
--! @return the token, the remaining substring
--! @see #matchtoken()
function stringio.nexttoken(str, delim)
	delim = delim or "%s" -- here %s is an alias for any whitespace
	local pattern = string.format("([%s]*)([^%s]+)([%s]?)", delim, delim, delim) -- here %s is a string formatter as in C
	local discard1, token, discard2 = str:match(pattern)
--	print(string.format("'%s', '%s', '%s'", discard1, token, discard2))
	return token, str:sub(#token + #discard1 + #discard2 + 1)
end

--! Chops off the next matching token from the front of a string.
--! This function matches the first occurrence of specified pattern, extracting
--! and returning the matching substring, followed by the substring that follows
--! the match. This function differs from #nexttoken() in that it finds a
--! positive match, rather than the first thing it finds that doesn't match a
--! delimiter pattern.
--! @param str the string to tokenize
--! @param pattern the pattern to match against
--! @return the token, the remaining substring
--! @see #nexttoken()
function stringio.matchtoken(str, pattern)
	local tstart, tend = str:find(pattern)
	local token = str:sub(tstart, tend)
	return token, str:sub(tend + 1)
end

--! Tries to convert a string into a number.
--! 
--! <p>This function attempts to parse a string as a numeric value, and convert
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
--! <li> "1"
--! <li> \c "1."
--! <li> \c ".1"
--! <li> \c "1.0"
--! <li> \c "  3.14159"
--! <li> \c " -1.48532e-12 "
--! </ul>
--! 
--! <p>Some examples of invalid numeric strings:</p>
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
	return tonumber(val) or tonumber(tostring(val))
end

--! Reads a single line from file.
--! Reads text from file up to the first end-of-line char it finds.
--! The newline, if encountered, is discarded.
--! @param file descriptor object to read from. If omitted or \c nil,
--! 		uses the current input file.
--! @return a string containing the next line read from \c file, or \c nil
--! 		if it encounters EOF.
function stringio.readline(file)
	local file = file or io.input()
	return file:read("*line")
end

--! Prints its arguments to its output.
--! The behavior of this function can be modified depending on the first
--! argument that is passed in.
--! @param ... a list of arguments to print. If the first argument is:<ul>
--! 		<li>a function, it is called, and the returned value is used to
--! 			concatenate the items of the list;
--! 		<li>a file descriptor or file-like object, it is treated as the
--! 			output file, and printing is carried out by calling its
--! 			\c write() method;
--! 		<li>anything else, it is printed as a normal value, along with
--! 			all the other arguments.
--! 	</ul>
--! @see #printline()
function stringio.print(...)
	local args = {...}
	if #args == 0 then
		return
	end
	
	local arg1 = shift(args)
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
			out:write(arg1, unpack(args))
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
	local kvs = {}
	for k,v in pairs(t) do
		local fmt = getquotespec(k)..' = '..getquotespec(v)
		kvs[#kvs+1] = string.format(fmt, tostring(k), tostring(v))
	end
	return table.concat(kvs, sep)
end

return stringio