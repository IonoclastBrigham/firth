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
	--! @fn repl()
	--! @brief Executes the Firth Read-Eval-Print Loop.
	repl = function()
		if not c then
			c = compiler.new()
		else
			c.running = true
		end

		while c.running do
			stringio.print(c.compiling and '>>\t' or 'ok ')
			local success, msg = pcall(c.parse, c, stringio.readline(), 1)
			if not success then stringio.printline(msg) end
		end
		stringio.printline()
	end,

	--! @fn reload()
	--! @brief Reloads the firth compiler code.
	--! This is probably broken.
	reload = function()
		package.loaded['firth.compiler'] = nil
		_, compiler = assert(pcall(require, 'firth.compiler'))
	end
}

firth.repl()
