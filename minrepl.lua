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
local dictionary = firth.dictionary


local function REPL(clean, ...)
    -- print stack from previous line
    dictionary['?printstack'](...)

    -- error output / prompt
    firth([[
        if ." ok" else fmt" %s\n" .err end
        ` ➤ .
    ]], clean, ...)
    if dictionary.compiling then stringio.print('      ') end

    -- read input
    local line = stringio.readline()
    if line == nil then
        -- nil => EOF => CTRL+D
        stringio.print("bye")
        dictionary.bye(select(clean and 1 or 2, ...))
    end

    return REPL(pcall(firth.runstring, line, select(clean and 1 or 2, ...)))
end

if select("#", ...) > 0 then
    firth.runfile("firth/cli.firth")
    local src = table.concat({...}, " ")
    REPL(firth.runstring(src.." DOREPL not if printstack end DOREPL"))
else
    firth [[
        false =: showstack
        : ?printstack showstack if printstack end ;
    ]]
    dictionary.banner()
    REPL(true, ...)
end
