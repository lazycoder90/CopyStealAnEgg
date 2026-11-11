local Creatures = require("../../src/shared/Config/Creatures")
local Eggs = require("../../src/shared/Config/Eggs")
local Rarities = require("../../src/shared/Config/Rarities")
local Zones = require("../../src/shared/Config/Zones")
local EggRoll = require("../../src/shared/Logic/EggRoll")
local RNG = require("../../src/shared/Logic/RNG")

local function sum(list)
	local s = 0
	for _, v in list do
		s += v
	end
	return s
end

return function(t)
	local r = RNG.new(2024)
	local N = 100000

	-- Nest kecil
	local counts = { 0, 0, 0, 0, 0 }
	local inRange = true
	for _ = 1, N do
		local s = EggRoll.pickSlot(r, false)
		if s < 1 or s > 5 then
			inRange = false
		else
			counts[s] += 1
		end
	end
	t.truthy(inRange, "nest kecil slot 1..5")
	local total = sum(Eggs.smallNestWeights)
	for i, w in Eggs.smallNestWeights do
		t.near(counts[i] / N, w / total, 0.02, `small slot {i}`)
	end

	-- Grand nest
	local gcounts = { [6] = 0, [7] = 0, [8] = 0 }
	for _ = 1, N do
		local s = EggRoll.pickSlot(r, true, 5) -- luck diabaikan di grand
		gcounts[s] += 1
	end
	local gtotal = sum(Eggs.grandNestWeights)
	for i, w in Eggs.grandNestWeights do
		t.near(gcounts[5 + i] / N, w / gtotal, 0.02, `grand slot {5 + i}`)
	end

	-- Luck x2 menaikkan bobot slot >= 4 (nest kecil)
	local lcounts = { 0, 0, 0, 0, 0 }
	for _ = 1, N do
		lcounts[EggRoll.pickSlot(r, false, 2)] += 1
	end
	local w = table.clone(Eggs.smallNestWeights)
	w[4] *= 2
	w[5] *= 2
	local wt = sum(w)
	for i = 1, 5 do
		t.near(lcounts[i] / N, w[i] / wt, 0.02, `luck slot {i}`)
	end

	-- hatchTime
	local lo, hi = math.huge, 0
	for _ = 1, 2000 do
		local h = EggRoll.hatchTime(r, 3, 2)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	local base = Rarities.get(3).hatchBase * Zones.get(2).zoneFactor
	t.truthy(lo >= math.floor(base * 0.85), "hatchTime >= 0.85x")
	t.truthy(hi <= math.ceil(base * 1.15), "hatchTime <= 1.15x")
	t.truthy(EggRoll.hatchTime(r, 1, 1) >= 8, "hatchTime common z1")
	t.eq(EggRoll.hatchTime(r, 1, 1) % 1, 0, "hatchTime integer")

	-- rollEgg
	local egg = EggRoll.rollEgg(r, 4, false)
	local creature = Creatures.get(egg.speciesId)
	t.eq(creature.zone, 4, "egg zona")
	t.eq(creature.slot, egg.slot, "egg slot")
	t.eq(creature.rarity, egg.rarity, "egg rarity")
	t.truthy(egg.kg > 0 and egg.growTotal >= 1, "egg kg/growTotal")
	local grand = EggRoll.rollEgg(r, 7, true)
	t.truthy(grand.slot >= 6 and grand.slot <= 8, "grand egg slot")
	local a, b = EggRoll.rollEgg(RNG.new(5), 3, false), EggRoll.rollEgg(RNG.new(5), 3, false)
	t.truthy(
		a.speciesId == b.speciesId and a.kg == b.kg and a.growTotal == b.growTotal,
		"deterministik"
	)
end
