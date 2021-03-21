#!/usr/bin/env luajit
--------------------------------------------------------------------------------
--! @file
--! @brief Tiny minimal REPL for :Firth language.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2021 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--
-- Formatting:
--  utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------


local pcall = pcall
local table = table

local stringio = require "firth.stringio"
local firth = require "proto.bootstrap"
local runstring, runfile, dictionary = firth.runstring, firth.runfile, firth.dictionary


local function REPL(running, ...)
    if not running then
        dictionary.exit(1, ...)
    end

    -- prompt and read input
    stringio.print(dictionary.compiling and '      ' or 'ok> ')
    local line = stringio.readline()
    if line == nil then
        -- nil => EOF => CTRL+D
        stringio.print("bye")
        dictionary.bye(...)
    end

    return REPL(pcall(runstring, line, ...))
end

if select("#", ...) > 0 then
    runfile("firth/cli.firth")
    local src = table.concat({...}, " ")
    REPL(runstring(src.." DOREPL"))
else
    dictionary.banner()
    REPL(true, ...)
end
