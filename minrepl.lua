local pcall = pcall
local unpack = unpack or table.unpack

local stringio = require "firth.stringio"
local firth = require "proto.bootstrap"
local runstring, loadfile, dict = firth.runstring, firth.loadfile, firth.dict

local function REPL(running, ...)
    if not running then
        stringio.printline(...)
        stringio.printline("Goodbye 🖤")
        return
    end

    stringio.print('\nok> ')
    return REPL(pcall(runstring, stringio.readline(), ...))
end

loadfile "proto/core.firth"

if select("#", ...) > 0 then
    stringio.printline("<==[ "..table.concat({runstring(table.concat({...}, " "))}, " ").." ]")
else
    stringio.print(':MiniREPL, ')
    dict.banner()
    REPL(true, ...)
end
