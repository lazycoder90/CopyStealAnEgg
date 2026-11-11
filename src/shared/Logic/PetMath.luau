--!strict
-- Income/nilai pet dan telur (docs/PLAN.md §3.5, §3.11).

local Creatures = require("../Config/Creatures")
local Formulas = require("./Formulas")
local MutationLogic = require("./MutationLogic")

local PetMath = {}

function PetMath.petIncome(speciesId: string, kg: number, muts: { string }): number
	local c = Creatures.get(speciesId)
	return c.baseIncome * Formulas.weightMult(kg, c.baseKg) * MutationLogic.mult(muts)
end

PetMath.eggProjectedIncome = PetMath.petIncome

function PetMath.sellEggValue(speciesId: string, kg: number, muts: { string }): number
	return Formulas.sellEggValue(PetMath.petIncome(speciesId, kg, muts))
end

function PetMath.sellPetValue(speciesId: string, kg: number, muts: { string }): number
	return Formulas.sellPetValue(PetMath.petIncome(speciesId, kg, muts))
end

return PetMath
