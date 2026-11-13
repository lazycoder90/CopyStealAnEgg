local Creatures = require("../../src/shared/Config/Creatures")
local Data = require("../../src/shared/Models/HaloJellyData")

return function(t)
	local c = Creatures.get("halo_jelly")
	t.eq(c.zone, 1, "Halo Jelly di zona 1")
	t.eq(c.slot, 5, "Halo Jelly slot 5")
	t.eq(c.rarity, 3, "Halo Jelly rarity Rare")
	t.eq(Creatures.byId.acorn_squirrel, nil, "Acorn Squirrel sudah diganti")
	t.eq(#Data.cubes, 204, "204 kubus")
	local glow = 0
	for _, cube in Data.cubes do
		t.truthy(#cube == 14 and cube[13] >= 1 and cube[13] <= 4, "kubus valid")
		t.truthy(
			cube[4] >= cube[1] and cube[5] >= cube[2] and cube[6] >= cube[3],
			"ukuran tidak negatif"
		)
		if cube[14] then
			glow += 1
		end
	end
	t.eq(glow, 114, "114 kubus glow")

	local data = {
		eggs = { a = { id = "acorn_squirrel" }, b = { id = "moss_pup" } },
		pets = { p = { id = "acorn_squirrel" } },
		index = { found = { acorn_squirrel = true }, claimed = { acorn_squirrel = true } },
	}
	t.eq(Creatures.migrateProfile(data), 4, "4 penggantian")
	t.eq(data.eggs.a.id, "halo_jelly", "telur dimigrasi")
	t.eq(data.eggs.b.id, "moss_pup", "telur lain utuh")
	t.eq(data.pets.p.id, "halo_jelly", "pet dimigrasi")
	t.truthy(data.index.found.halo_jelly and data.index.found.acorn_squirrel == nil, "index found")
	t.truthy(
		data.index.claimed.halo_jelly and data.index.claimed.acorn_squirrel == nil,
		"index claimed"
	)
	t.eq(Creatures.migrateProfile(data), 0, "idempoten")
end
