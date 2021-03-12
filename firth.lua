--------------------------------------------------------------------------------
--! @file firth.lua
--! @brief Minimal frontend for Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2015-2021 Brigham Toskin
--!
--! <p>This file is part of the :Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--!
--! @see compiler.lua
--! @see stringio.lua
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


--! @cond
local stringio = require "firth.stringio"
local compiler = require "firth.compiler"
--! @endcond


--! The Firth repl and such.
--! This is rather shoddy code, atm.
local firth
firth = {
	instance = function()
		if not firth.c then
			firth.c = compiler.new()
		else
			firth.c.running = true
		end
		return firth.c
	end,

	doline = function(c, line, linenum)
		local success, msg = pcall(c.interpret, c, line, linenum)
		if not success then stringio.printline(msg) end
		return success
	end,

	--! @fn repl()
	--! @brief Executes the Firth Read-Eval-Print Loop.
	repl = function()
		local c = firth.instance()
		c.path = "REPL::INIT"
		firth.doline(c, 'copyright CR', 0)
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
			firth.doline(c, stringio.readline(), linenum)
		end
		stringio.printline()
	end,

	--! @fn cli()
	--! @brief runs each argument as a line of firth code.
	cli = function(args)
		local c = firth.instance()
		for i, code in ipairs(args) do
			c.path = "Argument"..i
			if not firth.doline(c, code, i) then
				break
			end
		end
		if c.stack.height > 0 then c:interpret(".S") end
		c.path = "stdin"
	end,
}

local args = {...}
if #args > 0 then
	firth.cli(args)
else
	args = nil
	firth.repl()
end
