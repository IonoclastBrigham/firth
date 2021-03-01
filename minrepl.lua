--------------------------------------------------------------------------------
--! @file minirepl.lua
--! @brief Tiny minimal REPL for :Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021 Brigham Toskin
--!
--! <p>This file is part of the :Firth language reference implementation. Usage
--! and redistribution of this software is governed by the terms of a modified
--! MIT-style license. You should have received a copy of the license with the
--! source distribution in the file LICENSE; if not, you may find it online at
--! <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE></p>
--
-- Formatting:
--  utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local pcall = pcall
local unpack = unpack or table.unpack

local stringio = require "firth.stringio"
local firth = require "proto.bootstrap"
local runstring, runfile, dict = firth.runstring, firth.runfile, firth.dict

local function REPL(running, ...)
    if not running then
        stringio.printline(...)
        stringio.printline("Goodbye 🖤")
        return
    end

    stringio.print(dict.compiling and '      ' or 'ok> ')
    return REPL(pcall(runstring, stringio.readline(), ...))
end

runfile "proto/core.firth"

if select("#", ...) > 0 then
    -- TODO: proper printstack word that doesn't care about nils
    stringio.printline("<==[ "..table.concat({runstring(table.concat({...}, " "))}, " ").." ]")
else
    stringio.print(':MiniREPL, ')
    dict.banner()
    REPL(true, ...)
end
