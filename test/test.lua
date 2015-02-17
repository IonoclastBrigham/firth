local io = require 'io'
local table = require 'table'


local failures = 0
local messages = {}
local mt = {}
mt.insert = table.insert
mt.__index = mt
setmetatable(messages, mt)

local function assert(bool, msg)
	if not bool then
		failures = failures + 1
		if msg then messages:insert(msg) end
		io.output():write 'E'
	else
		io.output():write '.'
	end
	return bool
end

local function dotests(path)
	local tests = assert(loadfile(path))
	if tests then
		tests = tests()
		for i,test in ipairs(tests) do
			assert(pcall(test))
		end
	end
	print()
end

dotests 'test/test-stack.lua'
dotests 'test/test-stringio.lua'

for _,msg in ipairs(messages) do
	print(msg)
end