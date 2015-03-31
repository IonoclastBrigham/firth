--------------------------------------------------------------------------------
--! @file firth.lua
--! @brief Minimal frontend for Firth language.
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

	doline = function(c, line)
		local success, msg = pcall(c.interpretline, c, line, 1)
		if not success then stringio.printline(msg) end
		return success
	end,

	--! @fn repl()
	--! @brief Executes the Firth Read-Eval-Print Loop.
	repl = function()
		local c = firth.instance()
		firth.doline(c, 'copyright CR')
		while c.running do
			stringio.print(c.compiling and '>>\t' or 'ok ')
			firth.doline(c, stringio.readline())
		end
		stringio.printline()
	end,

	--! @fn cli()
	--! @brief runs each argument as a line of firth code.
	cli = function(args)
		local c = firth.instance()
		for i, code in ipairs(args) do
			if not firth.doline(c, code) then
				stringio.printline("Error at argument "..i)
				break
			end
		end
		if c.stack.height > 0 then stringio.printstack(c.stack) end
	end,
}

local args = {...}
if #args > 0 then
	firth.cli(args)
else
	args = nil
	firth.repl()
end
