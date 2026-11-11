--!strict
-- Fuse 3 pet sama (docs/PLAN.md §4.13).

local Creatures = require("../Config/Creatures")
local Mutations = require("../Config/Mutations")
local Formulas = require("./Formulas")
local MutationLogic = require("./MutationLogic")
local PetMath = require("./PetMath")
local RNG = require("./RNG")

export type FusePet = { id: string, kg: number, muts: { string } }
export type FuseResult = {
	id: string,
	kg: number,
	muts: { string },
	upgraded: boolean,
	prism: boolean,
}

local FuseLogic = {}

function FuseLogic.canFuse(pets: { FusePet }): (boolean, string?)
	if #pets ~= 3 then
		return false, "Fuse needs exactly 3 pets"
	end
	local id = pets[1].id
	for _, p in pets do
		if p.id ~= id then
			return false, "All 3 pets must be the same creature"
		end
	end
	return true, nil
end

function FuseLogic.luck(pets: { FusePet }): number
	local sum = 0
	for _, p in pets do
		local base = Creatures.get(p.id).baseKg
		sum += Formulas.weightMult(p.kg, base) * MutationLogic.mult(p.muts)
	end
	return math.clamp(sum / 3 - 1, 0, 2)
end

function FuseLogic.cost(pets: { FusePet }): number
	local total = 0
	for _, p in pets do
		total += PetMath.petIncome(p.id, p.kg, p.muts)
	end
	return 10 * total
end

-- Spesies berikutnya: slot+1 di zona sama; slot 8 -> slot 1 zona berikutnya; ujung -> nil.
local function nextCreature(id: string): Creatures.Creature?
	local c = Creatures.get(id)
	if c.slot < 8 then
		return Creatures.byZone[c.zone][c.slot + 1]
	end
	local nextZone = Creatures.byZone[c.zone + 1]
	if nextZone then
		return nextZone[1]
	end
	return nil
end

function FuseLogic.fuse(rng: RNG.RNG, pets: { FusePet }): FuseResult
	local luck = FuseLogic.luck(pets)
	local first = Creatures.get(pets[1].id)

	-- Union mutasi: unik, urutan Mutations.order, maksimal 3.
	local present = {}
	for _, p in pets do
		for _, m in p.muts do
			present[m] = true
		end
	end
	local muts: { string } = {}
	for _, name in Mutations.order do
		if present[name] and #muts < Mutations.maxPerItem then
			table.insert(muts, name)
		end
	end

	local upgradeRoll = rng:chance(0.30 + 0.10 * luck)
	local prismRoll = rng:chance(0.02 + 0.03 * luck)

	local target = if upgradeRoll then nextCreature(first.id) else nil
	local id, kg, upgraded = first.id, 0, false
	if target then
		id, kg, upgraded = target.id, target.baseKg, true
	else
		for _, p in pets do
			kg += p.kg
		end
		kg *= 0.6
	end

	local prism = false
	if prismRoll and MutationLogic.canAdd(muts, "Prism") then
		muts = MutationLogic.add(muts, "Prism")
		prism = true
	end

	return { id = id, kg = kg, muts = muts, upgraded = upgraded, prism = prism }
end

return FuseLogic
