local io = require 'io'
local output = io.output()
local table = require 'table'


local failures = 0
local messages = {}
local mt = {}
mt.insert = table.insert
mt.__index = mt
setmetatable(messages, mt)

local function try(bool, msg)
	if not bool then
		failures = failures + 1
		if msg then messages:insert(msg) end
		output:write 'E'
	else
		output:write '.'
	end
	return bool, msg
end

local function failed(msg)
	output:write('E\n')
	messages:insert(msg)
	failures = failures + 1
end

local function dotests(path)
	local success, tests = pcall(loadfile, path)
	if success then
		success, tests = pcall(tests)
		if success then
			for _, test in ipairs(tests) do
				try(pcall(test))
			end
		else
			failed(tests)
		end
	else
		failed(tests)
	end
	output:write('\n')
end

-- TODO: parameterize this or automate it
dotests 'test/test-stack.lua'
dotests 'test/test-stringio.lua'

if failures > 0 then
	output:write(string.format("%d failed tests.\n", failures))
	for _, msg in ipairs(messages) do
		output:write(string.format("%s\n", msg))
	end
end