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


local compiler = require 'firth.compiler'
local stringio = require 'firth.stringio'


c = compiler.new()
while c.running do
	stringio.print 'ok '
	c:parse(stringio.readline())
end
