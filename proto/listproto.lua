-- Prototype code for 4 different list implementations
--	* a novel hash-link thingy
--	* a novel index-link thingy
--	* a traditional pair-based linked list
--	* an array-table-based thingy, for reference


local time = os.clock
local select = select


local NULL, pair, append, list, buildlist, car, cdr, eachcar, foreach

-- test rig util functions --

---[[
local function timeit(f, ...)
	local t0 = time()
	for i=1,100000 do f(...) end
	return time() - t0
end

local function gcoff()
	collectgarbage "stop"
	return collectgarbage "count" / 1024
end

local function gcon()
	local mem = collectgarbage "count" / 1024
	collectgarbage "restart"
	collectgarbage()
	collectgarbage()
	return mem
end

-- benchmark functions --

local function create10()
	local l = list(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
end

local sumaccumulator
local function sumhelper(k)
	sumaccumulator = sumaccumulator + k
end

local function foreach_sum1(l)
	sumaccumulator = 0
	foreach(l, sumhelper)
end

local function foreach_sum4(l1, l2, l3, l4)
	foreach_sum1(l1)
	foreach_sum1(l2)
	foreach_sum1(l3)
	foreach_sum1(l4)
end

local function foreach_sum8(l1, l2, l3, l4, l5, l6, l7 ,l8)
	foreach_sum4(l1, l2, l3, l4)
	foreach_sum4(l5, l6, l7, l8)
end

-- test rig apparatus --

local stats = {}

local function runtestsfor(name)
	local t, mem
	local total, memtotal, tests = 0, 0, 0

	print("\n**"..name.."**")

	mem = gcoff()
	t = timeit(create10)
	mem = gcon() - mem
	print("create10():\t", t.." secs, "..(mem).." MB")
	total = total + t
	memtotal = memtotal + mem
	tests = tests + 1

	mem = gcoff()
	local l = buildlist(1024, function(i) return i end)
	t = timeit(foreach_sum1, l)
	l = nil
	mem = gcon() - mem
	print("foreach_sum1(8K):", t.." secs, "..(mem).." MB")
	total = total + t
	memtotal = memtotal + mem
	tests = tests + 1

	mem = gcoff()
	l = buildlist(256, function(i) return i end)
	t = timeit(foreach_sum1, l)
	l = nil
	mem = gcon() - mem
	print("foreach_sum1(2K):", t.." secs, "..(mem).." MB")
	total = total + t
	memtotal = memtotal + mem
	tests = tests + 1

	mem = gcoff()
	do
		l = buildlist(64, function(i) return i end)
		local l2 = buildlist(64, function(i) return i end)
		local l3 = buildlist(64, function(i) return i end)
		local l4 = buildlist(64, function(i) return i end)
		t = timeit(foreach_sum4, l, l2, l3, l4)
	end
	l = nil
	mem = gcon() - mem
	print("foreach_sum4(4x512):", t.." secs, "..(mem).." MB")
	total = total + t
	memtotal = memtotal + mem
	tests = tests + 1

	mem = gcoff()
	do
		l = buildlist(32, function(i) return i end)
		local l2 = buildlist(32, function(i) return i end)
		local l3 = buildlist(32, function(i) return i end)
		local l4 = buildlist(32, function(i) return i end)
		t = timeit(foreach_sum8, l, l2, l3, l4, l, l2, l3, l4)
	end
	l = nil
	mem = gcon() - mem
	print("foreach_sum8(8x256):", t.." secs, "..(mem).." MB")
	total = total + t
	memtotal = memtotal + mem
	tests = tests + 1

	stats[name] = {total, (memtotal/tests)}
	print("Total: ", total.." secs")
	print("Average:", (memtotal/tests).." MB")
end

local function summary()
	local fastest, fname = math.huge, ""
	local smallest, sname = math.huge, ""

	for k, v in pairs(stats) do
		if v[1] < fastest then fastest, fname = v[1], k end
		if v[2] < smallest then smallest, sname = v[2], k end
	end
	
	print()
	print("Fastest Overall:\t", fname.."("..fastest.." secs)")
	print("Smallest on Average:", sname.."("..smallest.." MB)")
end
--]]

-- here down is the different implementations --

print("Each test run 100,000 times for each list implementation..")
print("Garbage collector is disabled for each test, with a cleanup step between them.")

collectgarbage()
collectgarbage()

---[[
do
	local L = setmetatable({}, { __mode = "k" })
	local NULL = {}

	function append(l, v)
		local node = {v=v}
		L[node] = NULL
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
	function list(...)
		return listrecursive({}, ...)
	end

	function buildlist(n, f)
		local l = {}
		for i=0,n-1 do append(l, f(i)) end
		return l
	end

	function car(l)
		return l.head.v
	end

	function cdr(l)
		return { head = L[l.head], tail = l.tail}
	end

	local function caritr(l, n)
		if not n then return end
		return  L[n], n.v
	end
	function eachcar(l)
		return caritr, l, l.head
	end

	function foreach(l, f)
		for _,v in eachcar(l) do f(v) end
	end

	runtestsfor "Hash-Linked"
end
--]]


---[=[
do
	NULL = setmetatable({0,0}, { __tostring = function(t) return "'()" end })
	local L = {}
	for i=1,256 do L[i] = 0 end

	local nexti = 1
	function append(l, v)
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
	function list(...)
		return listrecursive({0,0}, ...)
	end

	function buildlist(n, f)
		local l = {0,0}
		for i=0,n-1 do append(l, f(i)) end
		return l
	end

	function car(l)
		return L[l[1]]
	end

	function cdr(l)
		if l[1] == l[2] then return NULL end
		local next = l[1] + 1
		return { L[next], l[2] }
	end

	local function caritr(_, n)
		if n == 0 then return end
		local v = L[n]
		return L[n+1], v
	end
	function eachcar(l)
		return caritr, nil, l[1]
	end

	function foreach(l, f)
		for _,v in eachcar(l) do f(v) end
	end

	runtestsfor "Index-Linked"
end
--]=]


---[[
do
	NULL = setmetatable({}, { __tostring = function(t) return "'()" end })

	function pair(a, b)
		return {a, b}
	end

	function append(l, v)
		-- first, make sure we're at the tail position
		if l[2] ~= NULL then return append(l[2], v) end
		l[2] = pair(v, NULL)
	end

	local function listr(head, curr, ...)
		if select("#", ...) == 0 then curr[2] = NULL; return head end
		local l = {(...)}
		curr[2] = l
		return listr(head, l, select(2, ...))
	end
	function list(...)
--		if select("#", ...) == 0 then return NULL end
--		return pair((...), list(select(2, ...)))

--		local l = {(...)}
--		local current = l
--		for i=2,select("#", ...) do
--			local new = {(select(i, ...))}
--			current[2] = new
--			current = new
--		end
--		current[2] = NULL

		local l = {(...)}
		return listr(l, l, select(2, ...))
	end

	function buildlist(n, f)
		if n < 1 then return NULL end
		local l = pair(f(0), NULL)
		for i=1,n-1 do append(l, f(i)) end
		return l
	end

	function car(p)
		return p[1]
	end

	function cdr(p)
		return p[2]
	end

	local function caritr(_, l)
		if l == NULL then return end
		return l[2], l[1]
	end
	function eachcar(l)
		return caritr, nil, l
	end

	function foreach(l, f)
		for _,v in eachcar(l) do f(v) end
	end
	
	runtestsfor "Traditional"
end
--]]


---[[
do
	function append(l, v)
		local len = l.n + 1
		l[len] = v
		l.n = len
	end

	function list(...)
		return {n = select("#", ...); ...}
	end

	function buildlist(n, f)
		if n < 1 then return list() end
		local l = list()
		for i=1,n do append(l, f(i-1)) end
		return l
	end

	function car(l)
		return l[1]
	end

	local unpack = table.unpack
	function cdr(l)
		if l.n < 2 then return list() end
		return { n = l.n - 1; unpack(l, 2) }
	end

--	local function caritr(_, i)
--	end
	function eachcar(l)
--		local i = 1
--		return function()
--			if i > l.n then return end
--			local v = l[i]
--			i = i + 1
--			return v
--		end
		return ipairs(l)
	end

	function foreach(l, f)
		for _,v in eachcar(l) do f(v) end
	end
	
	runtestsfor "Array-Tables"
end
--]]


summary()





--[[
--local l = {}
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
--]]
