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
local runstring, runfile, dictionary = firth.runstring, firth.runfile, firth.dictionary

local function freeze(...)
    local frozenstack = {...}
    frozenstack.height = dictionary.height(...)
    return frozenstack
end

local function spread(frozenstack, i)
    i = i or 1
    if i <= frozenstack.height then
        return frozenstack[i], spread(frozenstack, i + 1)
    end
end

local function REPL(running, ...)
    if not running then
        stringio.printline(...)
        stringio.printline("Goodbye 🖤")
        return
    end

    stringio.print(dictionary.compiling and '      ' or 'ok> ')
    return REPL(pcall(runstring, stringio.readline(), ...))
end

if select("#", ...) > 0 then
    local src = table.concat({...}, " ")
    local frozenstack = freeze(runstring(src))
    stringio.print("\n<==[ ")
    dictionary[".S"](spread(frozenstack))
    stringio.printline("]")
else
    stringio.print(':MiniREPL, ')
    dictionary.banner()
    REPL(true, ...)
end
