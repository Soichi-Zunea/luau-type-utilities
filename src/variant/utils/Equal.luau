--!strict

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
	Whether two types are equivalent
	@ Used when == doesn't produce the expected output
	
	@param a a type to compare
	@param b a type to compare
	
	@returns a singleton boolean type
	
	@example
	-- Rarely used as types in practice, mainly used in user-defined types for validity
	type Sample1 = equal<{[{a: number}]: number}, {[{a: number}]: number}>
	type Sample2 = equal<<A,C,D,F...>(F...)->(A,C,D), <A,C,D,F...>(F...)->(A,C,D)>
	type Sample3 = equal<{a: "Hello"}, {a: "hello"}>

	local sample1: Sample1 -- true singleton type
	local sample2: Sample2 -- true singleton type
	local sample3: Sample3 -- false singleton type

]]--
export type function equal(a: type, b: type)
	local t = types.singleton(true)
	local f = types.singleton(false)
	
	-- This statement does not work as intended due to a bug
	-- See: https://github.com/luau-lang/luau/issues/1794
	if a == b then return t end
	if getType(a) ~= getType(b) then return f end
	
	local comb = function()
		local aComp = a:components()
		local bComp = b:components()
		if #bComp ~= #aComp then return f end
		for i,v in aComp do
			if not equal(v, bComp[i]):value() then return f end
		end
		return t
	end
	local tableP = function()
		-- check properties, indexer, metatable
		local aComp = a:metatable()
		local bComp = b:metatable()
		if (not aComp or not bComp) and aComp ~= bComp then
			return f 
		end
		if aComp then
			if not equal(aComp, bComp):value() then
				return f
			end
		end
		aComp = a:indexer()
		bComp = b:indexer()
		if (not aComp or not bComp) and aComp ~= bComp then
			return f 
		end
		if aComp then
			if not equal((aComp :: any).index, (bComp :: any).index):value() 
				or not equal((aComp :: any).readresult, (bComp :: any).readresult):value()
				or not equal((aComp :: any).writeresult, (bComp :: any).writeresult):value()
			then
				return f
			end
		end
		aComp = a:properties() :: {[type]: { read: type?, write: type? } }
		bComp = b:properties() :: {[type]: { read: type?, write: type? } }
		for i,v in aComp do
			-- THIS is the hardest part
			local bv = bComp[i]
			
			if not bv then
				-- may be able to add some more, but this is a good base
				if i:is("nil")
					or i:is("unknown") or i:is("never")
					or i:is("any") or i:is("boolean")	
					or i:is("number") or i:is("string")	
				then
					return f
				end
				for s,t in bComp do
					if equal(i,s):value() then 
						bv = t 
						break 
					end
				end
				if not bv then return f end
			end
			if (not bv.read or not v.read) and bv.read ~= v.read
				or (not bv.write or not v.write) and bv.write ~= v.write
			then
				return f
			end
			if v.read then
				if not equal(v.read, bv.read):value() then
					return f
				end
			end
			if v.write then
				if not equal(v.write, bv.write):value() then
					return f
				end
			end
		end
		return t
	end
	local classP = function(aComp, bComp)
		if (not aComp or not bComp) and aComp ~= bComp then
			return f
		end
		if aComp then
			if not equal(aComp, bComp):value() then
				return f
			end
		end
		return t
	end
	local func = function(aComp, bComp)
		if (not aComp.tail or not bComp.tail) and aComp.tail ~= bComp.tail
			or (not aComp.head or not bComp.head) and aComp.head ~= bComp.head	
		then 
			return f 
		end
		if aComp.tail then
			if not equal(aComp.tail, bComp.tail):value() then
				return f
			end
		end
		if aComp.head then
			if #bComp.head :: {} ~= #aComp.head :: {} then
				return f 
			end
			for i,v in aComp.head :: {type} do
				if not equal(v, (bComp.head :: {type})[i]):value() then
					return f 
				end
			end
		end
		return t
	end
	
	local tab = {
		singleton = function()
			return a:value() == b:value()
				and t or f
		end,
		generic = function()
			return a:name() == b:name() and a:ispack() == b:ispack() 
				and t or f
		end,
		negation = function()
			return equal(a:inner(), b:inner()):value()
		end,
		union = comb,
		intersection = comb,
		table = tableP,
		class = function()
			-- basically table, but with read/write parents
			if not classP(a:readparent(),b:readparent()):value() then
				return f 
			end
			if not classP(a:writeparent(),b:writeparent()):value() then
				return f 
			end
			return tableP()
		end,
		['function'] = function()
			-- check params, returns, and generics
			local aComp = a:generics()
			local bComp = b:generics()
			if #bComp ~= #aComp then return f end
			for i,v in aComp do
				if not equal(v, bComp[i]):value() then return f end
			end
			if not func(a:returns(), b:returns()):value() then 
				return f 
			end
			if not func(a:parameters(), b:parameters()):value() then
				return f 
			end
			return t
		end,
	}
	return tab[getType(a)]()
end


type function deduplicate(...: type)
	
	-- naive approach
	local args = {...}
	local lenArgs = #args
	local temp = {}
	for i,v in args do
		local broke = false
		for s=i+1, lenArgs do
			if equal(v,args[s]):value() then
				broke = true
				break
			end
		end
		if not broke then
			temp[#temp+1] = v
		end
	end
	
	return temp
end

--[[
	Returns the intersection of the provided types
	
    @ Should ANY of the types input be a singleton and any of the other 
    	singletons not match the initial singleton’s value, it will 
    	error.
    @ Should ANY of the types input be a singleton, the output WILL be 
    	a singleton and NOT an intersection, UNLESS there is a type 
    	conflict, in which case it will error.
    @ Should ANY of the types input conflict, it will error.
    @ Removes duplicates
	
	@param ... the types to be combined via intersection
]]--
export type function intersect(...: type)
	local args = {}
	
	-- Deconstruct any intersections within?
	local function mergeIntersection(...)
		for i,v in {...} do
			if v:is("union") then
				mergeIntersection(unpack(v:components() :: any))
				continue
			end
			args[#args + 1] = v
		end
	end

	-- Recursively merges intersections into args
	mergeIntersection(...)
	
	local single = nil
	
	-- Verifies that singletons of different values cannot be intersected
	for _,v in args do
		if v:is("singleton") then
			if single ~= nil and single:value() ~= v:value() then
				print(`Cannot intersect singletons {
					single:value()} and {v:value()}`)
				return types.never
			end
			single = v
		end
	end

	-- Checks for type conflicts
	if single then
		local acceptableTypes = {
			"any", "singleton", typeof((single :: type):value()), "unknown"
		}
		for _,v in args do
			local isBroken = nil
			for _, acceptableType in acceptableTypes do
				-- if negation, ensure that the inner isn't ~typeSingle or ~single
				-- if intersection, MUST be acceptableTypes or single
				-- if union, MUST be acceptableTypes or single
				if v:is(acceptableType) then
					isBroken = true
					break
				end
			end
			if not isBroken then
				print(`Type conflicts: Got {
					getType(v)
					}, expected any, singleton, {
					typeof(single:value())
					}, or unknown`)
				return types.never
			end
		end
		return single
	end

	local acceptableTypes = {
		"any", "unknown"
	}
	-- Morphs acceptableTypes until it matches all existing types
	-- tables, unions, intersections, and negations will be difficult
	for _, v in args do

	end

	-- Remove duplicate types
	args = deduplicate(unpack(args)) :: any
	if #args > 1 then
		return types.intersectionof(unpack(args :: any)) :: type
	end
	return args[1]
end


--[[
	Returns the union of the provided types
	@ Removes duplicates
	@ Recursively combines unions into one union
	
	@param ... the types to be combined via union
]]--
export type function union(...: type)
	local args = {}
	local function mergeUnion(...)
		for i,v in {...} do
			if v:is("union") then
				mergeUnion(unpack(v:components() :: any))
				continue
			end
			args[#args + 1] = v
		end
	end
	
	-- Recursively merges unions into args
	mergeUnion(...)
	
	-- Remove duplicate types
	args = deduplicate(unpack(args))
	
	if #args > 1 then
		return types.unionof(unpack(args :: {type})) :: type
	end
	return args[1] :: type
end


--[[
	Verifies that the constrained type fits into the constraint type.
	@ Currently an issue with tables due to: 
		https://github.com/luau-lang/luau/issues/1794
	
	@param a the constrained type
	@param b the constraint type
	
	@returns the constrained type if it is truely constrained, 
		else it produces an error and never type
		
	@example
	type Fruit = "Fruit" | string
	type ConstrainToFruit<A> = constrain<A, Fruit>

	-- Shows that "Apple cannot fit inside Fruit", 
	--	BUT since "Apple" is a string, will still return itself
	--	Only worry when the returned type is never
	type Apple = ConstrainToFruit<"Apple">
	
]]--
export type function constrain(a: type, b: type)
	-- Bugged
	-- See: https://github.com/luau-lang/luau/issues/1794
	if equal(a,b):value() then 
		return a 
	end
	
	local typeA = getType(a)
	
	-- Recursively goes through a until it is the simplest form
	if typeA == 'never' then
		print("Never can NEVER fit inside another type that isn't never.")
		return types.never
	elseif typeA == 'negation' then
		if constrain(a:inner(), b):is("never") then
			return a -- correct?
		end
		print(`First arg {typeA} doesn't fit into {getType(b)}`)
		return types.never
	
	elseif typeA == 'union' then
		-- One met
		local broken = false
		for _,v in a:components() do
			if not constrain(v, b):is("never") then
				broken = true
				break
			end
		end
		if broken then
			return a
		end
		print("At least one component of a union MUST be met.")
		return types.never
	elseif typeA == 'intersection' then
		-- All met
		local broken = false
		for _,v in a:components() do
			if constrain(a, v):is("never") then
				broken = true
				break
			end
		end
		if broken then
			print("ALL of the components of an intersection must be met.")
			return types.never
		end
		return a
	end
	
	-- Recursively goes through b until it is the simplest form
	local typeB = getType(b)
	if typeB == 'any' or typeB == 'unknown' then
		return a
	elseif typeB == 'never' then
		print("Only never can fit inside never.")
		return types.never
	elseif typeB == 'negation' then
		
		-- Union: None of the components can be met
		-- Intersection: At least of the components must not be met
		if constrain(a, b:inner()):is("never") then
			return a -- twisted logic~
		end
		print(`First arg {typeA} doesn't fit into {typeB}`)
		return types.never
		
	elseif typeB == 'union' then
		-- At least one of the components MUST be met
		local broken = false
		for _,v in b:components() do
			if not constrain(a, v):is("never") then
				broken = true
				break
			end
		end
		if broken then
			return a
		end
		--print("At least one component of a union MUST be met.")
		return types.never
	elseif typeB == 'intersection' then
		-- ALL of the components must be met
		local broken = false
		for _, v in b:components() do
			if constrain(a, v):is("never") then
				broken = true
				break
			end
		end
		if broken then
			print("ALL of the components of an intersection must be met.")
			return types.never
		end
		return a
	else
		-- a must be within b, simplest form***
		
		if typeB == 'boolean' and typeA == 'singleton'
			and type(a:value()) == 'boolean' then
			return a
			
		elseif typeB == 'string' and typeA == 'singleton'
			and type(a:value()) == 'string' then
			return a
			
		elseif typeB == 'number' and typeA == 'singleton'
			and type(a:value()) == 'number' then
			return a -- DNE currently
			
		end
		
		if typeA ~= typeB then
			print(`First arg {typeA} doesn't fit into {typeB}`)
			return types.never
		end
		
		if typeB == 'table' or typeB == 'class' then
			-- go through each element and constrain
			-- most cases, it is a single 'or nil' statement
			
			local aComp = a:metatable()
			local bComp = b:metatable()
			if not bComp and aComp ~= bComp then
				print("Metatables don't match, expected nil")
				return types.never
			end
			if bComp then
				if constrain(aComp, bComp):is("never") then
					print("Metatables don't match")
					return types.never
				end
			end
			aComp = a:indexer()
			bComp = b:indexer()
			if not bComp and aComp ~= bComp then
				print("Indexers don't match, expected nil")
				return types.never
			end
			if bComp then
				if constrain((aComp :: any).index, (bComp :: any).index):is("never") 
					or constrain((aComp :: any).readresult, (bComp :: any).readresult):is("never")
					or constrain((aComp :: any).writeresult, (bComp :: any).writeresult):is("never")
				then
					print("Indexers don't match")
					return types.never
				end
			end
			aComp = a:properties()
			bComp = b:properties()
			for i,v in bComp do
				-- using strats of equal, but what do I do?
				local av = aComp[i]
				if not av then
					if i:is("nil")
						or i:is("unknown") or i:is("never")
						or i:is("any") or i:is("boolean")	
						or i:is("number") or i:is("string")	
					then
						print("Element is not in constrainment")
						return types.never
					end
					for s,t in aComp do
						if not constrain(i,s):is("never") then 
							av = t 
							break
						end
					end
					if not av then
						print("Element missing from table")
						return types.never
					end
				end
				if (not av.read or not v.read) and av.read ~= v.read
					or (not av.write or not v.write) and av.write ~= v.write
				then
					print("Mismatching read types or write types.")
					return types.never
				end
				if v.read then
					if constrain(v.read, av.read):is("never") then
						print("Read properties aren't constrained")
						return types.never 
					end
				end
				if v.write then
					if constrain(v.write, av.write):is("never") then
						print("Write properties aren't constrained")
						return types.never 
					end
				end
			end
			return a
		elseif typeB == 'function' then
			-- check params, returns, and generics
			local aComp = a:generics()
			local bComp = b:generics()
			for i,v in aComp do
				if bComp[i] then continue end
				if constrain(v, bComp[i]):is("never") then
					print("Generic types don't match")
					return types.never
				end
			end
			
			local func = function(aComp, bComp)
				if not bComp.tail and aComp.tail ~= bComp.tail
					or not bComp.head and aComp.head ~= bComp.head	
				then 
					print("Tail or head types don't match, expected nil")
					return types.never
				end
				if aComp.tail then
					if constrain(aComp.tail, bComp.tail):is("never") then
						print("Tail is not constrained")
						return types.never
					end
				end
				if aComp.head then
					for i,v in aComp.head :: {type} do
						if constrain(v, (bComp.head :: {type})[i]):is("never") then
							print("Head is not constrained")
							return types.never
						end
					end
				end
				return a -- is this correct?
			end
			if func(a:returns(), b:returns()):is("never") then 
				return types.never
			end
			if func(a:parameters(), b:parameters()):is("never") then
				return types.never 
			end
			return a
		else
			-- just in case they add other types
			print(`{
					typeA == 'singleton' and a:value() or typeA
				} doesn't fit into {
					typeB == 'singleton' and b:value() or typeB
				}`)
			return types.never
		end
	end	
end


return nil