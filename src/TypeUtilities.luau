--!strict

--[[
	-- <major>.<minor>.<bug>
	Version: 0000.0002.0003

	Unstable!
	Waiting on the ability to use required user-defined functions 
		within user-defined functions in the script to properly 
		organize everything.
	
	Incomplete: There are still many more type functions to add
		Alot of the functions are not started
		
	List of complete functions:
		Utils.equal
		Utils.negate
		Utils.union
		Utils.assert
		Utils.assertf
		Utils.printType
		Utils.prettyPrint
		Set.constrain
		
	
	List of uncompleted, but started (however slightly), functions:
		Table.rawgrab
		Table.get<X,Y>: Combines intersections/unions then performs 
			index
		Table.combine<...>: For intersections, all, for unions, we 
			remove all types that are subsets of the existing
		Table.rawcombine
		Table.rawchange
		Table.set
		Table.rawsetmetatable
		Table.rawgetmetatable
	
	Plans:
		Boolean logical functions (or, and, not, xor)
		Number arithmetic functions (math library and bit32 library 
			and <= / <)
		String base functions (just string library)
		Table functions (table library in part)
		
		Utils.intersect
		Set.contains<X,Y>: X contains Y, returns X if contained else 
			error.
		Set.subset<X,Y>: X is a subset of Y, returns X if subset else 
			error.
		Table.pack< X >: X is a union or intersection, returns a 
			table version.
			
			If the components are not tables it assumes {[number]: V} 
			where V is a union or intersection of the components
		Table.filter<X,Y>: X is the table to filter using Y's type, 
			only matching types will stay within (looks at value's 
			type).
		Table.filterk<X,Y>: X is the table to filter using Y's type,
			only the matching types will stay within (looks at the 
			key's type)
		
		Lower priority:
		String.intersect<...>: Returns the characters that are 
			present in both strings
		String.orderedintersect<...>: Returns the characters that 
			match the same positions and values in the string
		Union.filterKeys<X,Y>: Returns union of tables or table 
			that contains a key of specified type.  Keys are input
			as an intersection of types, a single type, or a table 
			with keys.
		Union.filterProperties<X,Y>: Returns union of tables or 
			table that contains key-value pairs of specific type.  
			Properties are input as tables or intersections thereof.
		Set.propersubset<X,Y>: X is a proper subset of Y, returns X if 
			proper subset else false.
		Set.complement<X,Y>: set difference, returns complement type.
		Set.symmetricdiff<X,Y>: symmetric difference, returns the type.
		Set.product<X,Y>: Returns the cartesian product of X and Y.
		Set.power< X >: Returns the power set of X.
	
	Changelog:
		0.0.0
			Utils
				Added equal and negate
				Added prettyPrintType and printType
				Added printValuesOfType and printValuesOfType
		0.1.1
			Utils
				Changed prettyPrintType's name to be prettyPrint
				Changed prettyPrint to be more consistent with the hover tips
				Made prettyPrint more readable (the code was horrid prior)
				Added assert and assertf
				Added intersect and union
				Removed printValuesOfType and printValuesOfType
		0.1.2
			Utils
				Added support for buffer and thread types
				Made equal more readable
				Updated assert to be an example of how to use assertf
		0.2.3
			Utils
				Modified negate to be more consistent with 'not'
				Modified union to remove duplicates and recursively 
					combine unions prior
				Added constrain to force a type to fit within another
					will show a message
				Temporarily removed intersection until completion
				Fixed a bug with equal in regards to negate
				Identified a bug within equal caused by the new solver.
					type A = equal<{a: number}, {b: number}> -- true, should be false
					type A = equal<{a: number, b: string}, {c: number, d: string}> -- true, should be false
				
				
]]--

local Utils = require("./variant/Utils")

-- Simple Examples
local a: Utils.equal<{}, number>
local b: Utils.printType<{a: "Hello"}>
local c: Utils.prettyPrint<{[{a: "World"}]: number}>
local f: Utils.negate<true>

local TypeUtilities = {}
return TypeUtilities