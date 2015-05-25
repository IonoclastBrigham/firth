local select = select

--[[
local L = setmetatable({}, { __mode = "k" })

local function append(l, v)
	local node = {v=v}
	if not l.head then
		l.head = node
	else
		L[l.tail] = node
	end
	l.tail = node
end

local function listrecursive(l, ...)
	if select("#", ...) == 0 then return l end
	append(l, (...))
	return listrecursive(l, select(2, ...))
end
local function list(...)
	return listrecursive({}, ...)
end

local function buildlist(n, f)
	local l = {}
	for i=0,n-1 do append(l, f(i)) end
	return l
end

local function car(l)
	return l.head.v
end

local function cdr(l)
	return { head = L[l.head], tail = l.tail}
end

local function lvalues(l)
	local next = l.head
	local prev
	return function()
		if not next or prev == l.tail then return end
		local node = next
		prev = next
		next = L[node]
		return node.v
	end
end

local function foreach(l, f)
	for v in lvalues(l) do f(v) end
end
]]


--[=[
local NULL = setmetatable({0,0}, { __tostring = function(t) return "'()" end })
local L = {}
for i=1,256 do L[i] = NULL end

local nexti = 1
local function append(l, v)
	local idx = nexti; nexti = nexti + 2 -- XXX
	L[idx] = v			-- node.v = v
	if l[1] == 0 then
		l[1] = idx		-- head = node
	else
		L[l[2]+1] = idx	-- tail.next = node
	end
	l[2] = idx			-- tail = node
end

local function listrecursive(l, ...)
	if select("#", ...) == 0 then return l end
	append(l, (...))
	return listrecursive(l, select(2, ...))
end
local function list(...)
	return listrecursive({0,0}, ...)
end

local function buildlist(n, f)
	local l = {0,0}
	for i=0,n-1 do append(l, f(i)) end
	return l
end

local function car(l)
	return L[l[1]]
end

local function cdr(l)
	if l[1] == l[2] then return {0,0} end
	local next = l[1] + 1
	return { L[next], l[2] }
end

local function lvalues(l)
	local next = l[1]
	local prev = 0
	return function()
		if next == 0 or prev == l[2] then return end
		local v = L[next]
		prev = next
		next = L[next+1]
		return v
	end
end

local function foreach(l, f)
	for v in lvalues(l) do f(v) end
end
]=]


--[[
local NULL = {}

local function pair(a, b)
	return {a, b}
end

local function append(l, v)
	if l[2] ~= NULL then return append(l[2], v) end
	l[2] = pair(v, NULL)
end

local function listrecursive(head, p, ...)
	if select("#", ...) == 0 then return head end
	p[2] = pair((...), NULL)
	return listrecursive(head, p[2], select(2, ...))
end
local function list(...)
	local head = pair((...), NULL)
	return listrecursive(head, head, select(2, ...))
end

local function buildlist(n, f)
	if n < 1 then return NULL end
	local l = pair(f(0), NULL)
	for i=1,n-1 do append(l, f(i)) end
	return l
end

local function car(p)
	return p[1]
end

local function cdr(p)
	return p[2]
end

local function lvalues(l)
	return function()
		if l == NULL then return end
		local v = l[1]
		l = l[2]
		return v
	end
end

local function foreach(l, f)
	for v in lvalues(l) do f(v) end
end
]]


local function append(l, v)
	local len = l.n + 1
	l[len] = v
	l.n = len
end

local function list(...)
	return {n = select("#", ...); ...}
end

local function buildlist(n, f)
	if n < 1 then return list() end
	local l = list()
	for i=1,n do append(l, f(i-1)) end
	return l
end

local function car(l)
	return l[1]
end

local unpack = table.unpack
local function cdr(l)
	if l.n < 2 then return list() end
	return { n = l.n - 1; unpack(l, 2) }
end

local function lvalues(l)
	local i = 1
	return function()
		if i > l.n then return end
		local v = l[i]
		i = i + 1
		return v
	end
end

local function foreach(l, f)
	for v in lvalues(l) do f(v) end
end




-- local l = {}
--local l = {0,0}
--local l = pair(5, NULL)
 local l = list()
append(l, 5)
append(l, 10)
append(l, 15)
append(l, 20)
append(l, 25)
collectgarbage()
print("Append to List: ")
foreach(l, print)
--print("Node Store:")
--for node, next in pairs(L) do print(node.v, '->', next.v) end
--print("Node Store:")
--for i=1,10 do print(i, '->', L[i]) end

l = car(l)
collectgarbage()
print("\nList (car): ")
print(l)
--print("Node Store:")
--for node, next in pairs(L) do print(node.v, '->', next.v) end
--print("Node Store:")
--for i=1,10 do print(i, '->', L[i]) end

l = buildlist(5, function(n) return 5 * 10^n end)
collectgarbage()
print("\nBuild List: ")
foreach(l, print)
--print("Node Store:")
--for node, next in pairs(L) do print(node.v, '->', next.v) end
--print("Node Store:")
--for i=11,20 do print(i, '->', L[i]) end

l = cdr(l)
collectgarbage()
print("\nList (cdr): ")
foreach(l, print)
--print("Node Store:")
--for node, next in pairs(L) do print(node.v, '->', next.v) end
--print("Node Store:")
--for i=11,20 do print(i, '->', L[i]) end

l = list(9, 9, 9, 9, 9)
collectgarbage()
print("\nList(9, 9, 9, 9, 9): ")
foreach(l, print)
--print("Node Store:")
--for node, next in pairs(L) do print(node.v, '->', next.v) end
--print("Node Store:")
--for i=21,30 do print(i, '->', L[i]) end

