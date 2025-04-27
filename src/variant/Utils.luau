--!strict

local Equal = require("./utils/Equal")
local Stringify = require("./utils/Stringify")

export type equal<A,B> = Equal.equal<A,B>
export type prettyPrint<A> = Stringify.prettyPrint<A>
export type printType<A> = Stringify.printType<A>
export type assertf<A,B> = Stringify.assertf<A,B>


--[[
	Returns the negation of type a
	
	@param a the type to be negated
]]--
export type function negate(a: type)
	if a:is("negation") then
		return a
	end
	return types.negationof(a)
end


--[[
	Throws an error if the provided type is false or nil
	
	@param a the provided type
	
	@returns the provided type
]]--
export type assert<A> = assertf<A, "assertion failed">

-- For details
local Utils = {}
return Utils