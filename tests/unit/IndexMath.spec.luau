local CollectionConfig = require("../../src/shared/Config/CollectionConfig")
local Creatures = require("../../src/shared/Config/Creatures")
local IndexMath = require("../../src/shared/Logic/IndexMath")
local Zones = require("../../src/shared/Config/Zones")

return function(t)
	t.eq(IndexMath.totalSpecies(), 96, "total 96 spesies")

	-- reward cash = baseIncome * 120
	local pebble = Creatures.get("pebble_chick")
	t.near(IndexMath.cashReward("pebble_chick"), pebble.baseIncome * 120, 1e-9, "cash reward")

	-- speed reward: monotonik naik per slot dan per zona
	for zone = 1, Zones.count do
		for slot = 2, 8 do
			t.truthy(
				IndexMath.speedReward(zone, slot) > IndexMath.speedReward(zone, slot - 1),
				`speed naik per slot z{zone} s{slot}`
			)
		end
		if zone > 1 then
			for slot = 1, 8 do
				t.truthy(
					IndexMath.speedReward(zone, slot) >= IndexMath.speedReward(zone - 1, slot),
					`speed tidak turun antar zona z{zone} s{slot}`
				)
			end
		end
	end
	t.eq(IndexMath.speedReward(1, 1), 5, "zona 1 slot 1 = 5")
	t.eq(IndexMath.speedReward(1, 8), 12, "zona 1 slot 8 = 12")
	t.eq(IndexMath.speedReward(2, 2), 7, "zona 2 slot 2: 5+1+1000*0.0005*2")
	t.near(
		IndexMath.speedReward(12, 8),
		1e12 * 0.0005 * 8 + 12,
		1,
		"zona 12 slot 8 ~ rumus dokumen"
	)

	local cash, speed = IndexMath.rewards("moss_pup")
	t.near(cash, Creatures.get("moss_pup").baseIncome * 120, 1e-9, "rewards cash")
	t.eq(speed, IndexMath.speedReward(1, 2), "rewards speed")

	-- progres, zona lengkap, unclaimed
	local found, claimed = {}, {}
	t.eq(IndexMath.foundCount(found), 0, "found kosong")
	t.eq(IndexMath.unclaimedCount(found, claimed), 0, "unclaimed kosong")
	for i = 1, 3 do
		found[Creatures.byZone[1][i].id] = true
	end
	local n, total = IndexMath.zoneProgress(found, 1)
	t.eq(n, 3, "progres 3")
	t.eq(total, 8, "total 8")
	t.eq(#IndexMath.completedZones(found), 0, "belum lengkap")
	claimed[Creatures.byZone[1][1].id] = true
	t.eq(IndexMath.unclaimedCount(found, claimed), 2, "unclaimed 2")
	for _, c in Creatures.byZone[1] do
		found[c.id] = true
	end
	local done = IndexMath.completedZones(found)
	t.eq(#done, 1, "zona 1 lengkap")
	t.eq(done[1], 1, "zona 1 lengkap idx")
	t.eq(IndexMath.foundCount(found), 8, "found 8")
	t.eq(IndexMath.unclaimedCount(found, claimed), 7, "unclaimed 7")
	found["tidak_ada"] = true
	t.eq(IndexMath.foundCount(found), 8, "id asing diabaikan")

	local c2, s2 = IndexMath.totalRewards({ "pebble_chick", "moss_pup" })
	local c1a, s1a = IndexMath.rewards("pebble_chick")
	local c1b, s1b = IndexMath.rewards("moss_pup")
	t.near(c2, c1a + c1b, 1e-9, "total cash")
	t.eq(s2, s1a + s1b, "total speed")

	t.near(IndexMath.zoneBonus(3), 0.06, 1e-12, "bonus 3 zona = 6%")
	t.eq(#CollectionConfig.index.limited, 4, "4 limited")
end
