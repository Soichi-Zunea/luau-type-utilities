--!strict

--[[
	Returns whether the type is a table, singleton, nil, etc
]]--
type function getType(a: type)
	local listTypes = {
		"nil", "unknown", "never", "any", "singleton", "boolean",
		"number", "string", "generic", "negation", "union", 
		"intersection", "function", "class", "table",
		"buffer", "thread"
	}
	for _,v in listTypes do
		if a:is(v) then
			return v
		end
	end
	return "Invalid type"
end

--[[
	Prints the variant of the type, whether it is a singleton, 
	class, table, or anything.
	@ Is the simplest form of printing a type
	
	@param a the type to be printed
	
	@returns the input type
	
	@example
	-- Shows the type is singleton
	type Sample = printType<"Hello World!">
]]--
export type function printType(a: type)
	print(getType(a))
	return a
end


--[[
	Morphs a type into a string that can be printed, powerful 
	when used with print().
	@ Used to help make debugging user-defined types easier
	
	@param a the type to morph
	
	@returns a string representing the type
	
	@example
	-- Sample user-defined type to print a type
	type function prettyPrint(a: type)
		print(stringify(a))
		return a
	end
	-- Shows: Type Error: <A,B,C,D,E...>(A, B, <F>(C,D)->(F, E...))->(E...)
	type Salmon = prettyPrint<<A,B,C,D,E...>(A, B, <F>(C,D)->(F, E...))->(E...)>
]]--
type function stringify(a: type, b: type?)
	local aType = getType(a)
	
	-- ensures cyclic types are caught
	local verify = function(v: type, format: string?): string?
		if not format then
			format = "%s"
		end
		if b then
			local c = nil
			local value = nil
			if b == v then
				value = "*CYCLIC*"
			end
			local bType = getType(b)
			if bType == 'union' then
				c = types.unionof(a, unpack((b :: type):components()))
				for _,t in (b :: type):components() do
					if t == v then 
						value = "*CYCLIC*"
						break
					end
				end
			else
				c = types.unionof(a, b :: type)
			end
			if not value then
				value = stringify(v, c)
			end
			return (string :: any).format(format, value) :: string
		end
		return (string :: any).format(format, stringify(v, a)) :: string
	end
	local tab = {
		singleton = function()
			return a:is("string") and `{a:value()}` 
				or tostring(a:value() :: any)
		end,
		generic = function()
			return `{a:name()}{a:ispack() and "..." or ""}`
		end,
		negation = function()
			return verify(a:inner(), "~%s") 
		end,
		union = function(char: string)
			local word = ""
			for _,v in a:components() do
				word ..= verify(v, `%s {char} `) :: string
			end
			return word:sub(1, #word - 3)
		end,
		
		table = function()
			local word = "{"
			local indexer = a:indexer()
			if indexer then
				word ..= `{verify(indexer.index)}: {verify(indexer.readresult)}, `
			end
			for i,v in a:properties() do
				local read = v.read
				if read and v.write == read then
					word ..= `{verify(i)}: {verify(read)}, `
				end
			end
			-- do we want to print all indexes?
			-- metatable __index, requires Table.get and Utils.equal

			if word ~= "{" then
				word = word:sub(1, #word - 2)
			end
			return word .. "}"
		end,
		['function'] = function()
			local word = ""
			if #a:generics() > 0 then
				word = "<"
				for i,v in a:generics() do
					word ..= stringify(v) .. ", "
				end
				word = word:sub(1, #word - 2)
				word ..= ">"
			end
			word ..= "("
			local params = a:parameters()
			if params.head then
				for _,v in params.head do
					word ..= verify(v, "%s, ") :: string
				end
				if #params.head > 0 and not params.tail then
					word = word:sub(1, #word - 2)
				end
			end
			if params.tail then
				word ..= verify(params.tail) :: string
			end
			word ..= ") -> ("
			local returns = a:returns()
			if returns.head then
				for i,v in returns.head do
					word ..= verify(v, "%s, ") :: string
				end
				if #returns.head > 0 and not returns.tail then
					word = word:sub(1, #word - 2)
				end
			end
			if returns.tail then
				word ..= verify(returns.tail) :: string
			end
			word ..= ")"
			return word
		end,
	}
	tab.intersection = tab.union
	tab.class = tab.table
	local solve = tab[aType]
	if solve then
		return solve(aType == "intersection" and "&" or "|")
	else
		return aType
	end
end


--[[
	Pretty prints the type, whether it is a singleton, table, 
	cyclic function, anything.
	@ Limited by Roblox's documentation, but you can use plugins 
	to make it even prettier.
	@ Works with Instances, but they are extemely long
	
	@param a the type to be printed
	
	@returns the input type
	
	@example
	-- Shows "Hello World!"
	type Sample = prettyPrint<"Hello World!">
]]--
export type function prettyPrint(a: type)
	print(stringify(a))
	return a
end

--[[
	Throws an error with the specified message if the provided 
	type is false or nil
	
	@param a the provided type
	@param message the type to prettyPrint
	
	@returns the provided type
]]--
export type function assertf(a: type, message: type)
	if a:is("singleton") and (a:is("nil") or not a:value()) then
		prettyPrint(message)
		return types.never
	end
	return a
end

return nil