-- closures with continuations
local function thread(fa, fb, ...)
	if not fb then return fa end
	local next = thread(fb, ...)
	return function(...) return next(fa(...)) end
end
local continuations = thread(unpack(foothread))

-- closures, continuations, inlined operators
local function thread(fa, fb, ...)
	-- this version tries to inline known operators
	if not fb then return fa end
	local next = thread(fb, ...)
	if fa == add then
		return  function(n2, n1, ...)
			return next(n1+n2, ...)
		end
	elseif fa == sub then
		return function(n2, n1, ...)
			return next(n1-n2, ...)
		end
	elseif fa == mul then
		return function(n2, n1, ...)
			return next(n1*n2, ...)
		end
	else
		return function(...) return next(fa(...)) end
	end
end
local contsinline = thread(unpack(foothread))