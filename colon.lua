--------------------------------------------------------------------------------
--! @file
--! @brief Über-minimal firth->lua compiler for stage-1 bootstrapping.
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
local stringio = require "firth.stringio"
local stack = require "firth.faststack"
--! @endcond


local input
local compiling = false
local target, last
local stack, cstack = stack.new(), stack.new()
local push, pop = stack.push, stack.pop
local peek, unpack = stack.peek, stack.unpack
local clear, height = stack.clear, stack.height

local dictionary = {
	["char"] = function()
	end,
	["parse"] = function()
	end,
	[">NUM"] = function()
	end,
	[">STR"] = function()
	end,
	["{}"] = function()
	end,
	["@@"] = function()
	end,
	["!!"] = function()
	end,
	["create"] = function()
	end,
	["settarget"] = function()
	end,
	["compile"] = function()
	end,
	["interpret"] = function()
	end,
	["buildfunc"] = function()
	end,
	["bindfunc"] = function()
	end,
	["execute"] = function()
	end,
	["call"] = function()
	end,
	["binop"] = function()
	end,
}


local function compile(str)
end


--! The Firth repl and such.
--! This is rather shoddy code, atm.
local colon
colon = {
	instance = function()
		if not colon.c then
			colon.c = compiler.new()
		else
			colon.c.running = true
		end
		return colon.c
	end,

	doline = function(c, line, linenum)
		local success, msg = pcall(c.interpret, c, line, linenum)
		if not success then stringio.printline(msg) end
		return success
	end,

	--! @fn repl()
	--! @brief Executes the Firth Read-Eval-Print Loop.
	repl = function()
		local c = colon.instance()
		c.path = "REPL::INIT"
		colon.doline(c, 'copyright CR', 0)
		c.path = "stdin"
		local linenum
		while c.running do
			if c.compiling then
				linenum = linenum + 1
				stringio.print('>>\t')
			else
				linenum = 1
				stringio.print('ok ')
			end
			colon.doline(c, stringio.readline(), linenum)
		end
		stringio.printline()
	end,

	--! @fn cli()
	--! @brief runs each argument as a line of firth code.
	cli = function(args)
		local c = colon.instance()
		for i, code in ipairs(args) do
			c.path = "Argument"..i
			if not colon.doline(c, code, i) then
				break
			end
		end
		if c.stack.height > 0 then c:interpret(".S") end
		c.path = "stdin"
	end,
}

local args = {...}
if #args > 0 then
	colon.cli(args)
else
	args = nil
	colon.repl()
end
