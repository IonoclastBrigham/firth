local mt = {
	__call = function(self, ...)
		return self.func(...)
	end,
	__tostring = function(self)
		local str = self.str or '{'..self.name..'}'
		self.str = str
		return str
	end,
}
mt.__index = mt

local function new(name)
	return setmetatable({ name = name, src = {} }, mt)
end

-- export
firth = firth or {}
firth.entry = { new = new }
return firth.entry
