

local compiler = require 'firth.compiler'
local stringio = require 'firth.stringio'


c = compiler.new()
while c.running do
	stringio.print 'ok '
	c:parse(stringio.readline())
end
