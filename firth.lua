--------------------------------------------------------------------------------
--! @file firth.lua
--! @brief Minimal REPL for Firth language.
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
local _, stringio = assert(pcall(require, 'firth.stringio'))
local _, compiler = assert(pcall(require, 'firth.compiler'))

local c
--! @endcond


--! The Firth repl and such.
--! This is rather shoddy code, atm.
firth = {
	instance = function()
		if not c then
			c = compiler.new()
		else
			c.running = true
		end
		return c
	end,

	doline = function(c, line)
		local success, msg = pcall(c.interpretline, c, line, 1)
		if not success then stringio.printline(msg) end
	end,

	--! @fn repl()
	--! @brief Executes the Firth Read-Eval-Print Loop.
	repl = function()
		c = firth.instance()
		while c.running do
			stringio.print(c.compiling and '>>\t' or 'ok ')
			firth.doline(c, stringio.readline())
		end
		stringio.printline()
	end,

	--! @fn cli()
	--! @brief runs each argument as a line of firth code.
	cli = function(args)
		c = firth.instance()
		for _, code in ipairs(args) do
			firth.doline(c, code)
		end
	end,

	--! @fn reload()
	--! @brief Reloads the firth compiler code.
	--! This is probably broken.
	reload = function()
		package.loaded['firth.compiler'] = nil
		_, compiler = assert(pcall(require, 'firth.compiler'))
	end
}

local args = {...}
if #args > 0 then
	firth.cli(args)
else
	args = nil
	firth.repl()
end
