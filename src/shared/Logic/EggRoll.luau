--!strict
-- Roll telur dunia: slot, berat, dan waktu hatch (docs/PLAN.md §3.2-3.4).

local Creatures = require("../Config/Creatures")
local Eggs = require("../Config/Eggs")
local Rarities = require("../Config/Rarities")
local Zones = require("../Config/Zones")
local RNG = require("./RNG")
local WeightRoll = require("./WeightRoll")

local EggRoll = {}

export type EggResult = {
	speciesId: string,
	slot: number,
	rarity: number,
	kg: number,
	growTotal: number,
}

function EggRoll.pickSlot(rng: RNG.RNG, isGrand: boolean, luck: number?): number
	if isGrand then
		return 5 + rng:weighted(Eggs.grandNestWeights)
	end
	local weights = table.clone(Eggs.smallNestWeights)
	local l = luck or 1
	for slot = Eggs.luckSlotBoostFrom, #weights do
		weights[slot] *= l
	end
	return rng:weighted(weights)
end

function EggRoll.hatchTime(rng: RNG.RNG, rarityIndex: number, zoneIndex: number): number
	local base = Rarities.get(rarityIndex).hatchBase * Zones.get(zoneIndex).zoneFactor
	return math.max(1, math.floor(base * rng:range(0.85, 1.15) + 0.5))
end

function EggRoll.rollEgg(
	rng: RNG.RNG,
	zoneIndex: number,
	isGrand: boolean,
	luck: number?
): EggResult
	local slot = EggRoll.pickSlot(rng, isGrand, luck)
	local creature = Creatures.byZone[zoneIndex][slot]
	return {
		speciesId = creature.id,
		slot = slot,
		rarity = creature.rarity,
		kg = WeightRoll.roll(rng, creature.baseKg),
		growTotal = EggRoll.hatchTime(rng, creature.rarity, zoneIndex),
	}
end

return EggRoll
