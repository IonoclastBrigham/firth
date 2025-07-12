locals
---


A named Lua variable can only live 3 places: foo = bar // where is foo?

	1. a global name in table _G
	2. a "true local" in the VM stack frame
	3. a closure upvalue slot (over a VM stack local) on a function instance

Can we get a restricted version/subset of local functionality working?

	* MUST be declared in a named (?) colon def
	* MUST be declared before any other words are compiled-in
	* WILL NOT be available in nested scopes of any kind (e.g. if-body or loop)
	* WILL be reentrant, i.e. simple or (a -> b -> a) recusrion ok
	
	Hope here is that we can get a "wrapper scope" going relatively simply and
	easily, if we don't have to worry about propagating access into nested scopes.

	Can't do threading like we did before(?); must build lua source and compile.
	Compile a function that takes xts as args, with local access inlined, which
	when executed returns a fully scoped function with proper local access?

	We want to compile to the spiritual equivalent of:

	```lua
	-- ( playerID playing -- )
	dictionary["setPlaying"] = function(...)
		local playing = select(1, ...)
		execute(Table.get('play', getPlayerById(select(2, ...))), playing)
	end
	```

Problems...

	* This seems to force us back down the road of generating lua source
	* definitely re-complicates all the stuff I workd so hard to simplify
	* requires compiler to juggle TOS and make sure it stay consistent
	  * words get called in the right order
	  * params end up in the right place
	  * TOS chopped appropriately based on stack consumed by locals
	
