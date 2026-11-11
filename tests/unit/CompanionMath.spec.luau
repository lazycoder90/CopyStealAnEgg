local CompanionMath = require("../../src/shared/Logic/CompanionMath")

return function(t)
	t.eq(#CompanionMath.questsFor(1), 2, "stage 1 dua quest")
	t.eq(#CompanionMath.questsFor(4), 1, "stage 4 satu quest")
	t.eq(CompanionMath.clampStage(9), 4, "clamp atas")
	t.eq(CompanionMath.clampStage("x"), 1, "clamp tipe salah")

	local grab, hatch = CompanionMath.questsFor(1)[1], CompanionMath.questsFor(1)[2]
	t.truthy(CompanionMath.matches(grab, "EggGrabbed", { zone = 1, rarity = 1 }), "grab zona 1")
	t.eq(CompanionMath.matches(grab, "EggGrabbed", { zone = 2 }), false, "zona salah")
	t.eq(CompanionMath.matches(grab, "EggHatched", { zone = 1 }), false, "event salah")
	t.truthy(CompanionMath.matches(hatch, "EggHatched", { zone = 7, rarity = 1 }), "hatch bebas")

	local steal = CompanionMath.questsFor(3)[1]
	t.truthy(CompanionMath.matches(steal, "EggPlaced", { stolen = true }), "stolen")
	t.eq(CompanionMath.matches(steal, "EggPlaced", { stolen = false }), false, "bukan curian")
	local astral = CompanionMath.questsFor(3)[2]
	t.eq(CompanionMath.matches(astral, "EggHatched", { rarity = 6 }), false, "Mythic kurang")
	t.truthy(CompanionMath.matches(astral, "EggHatched", { rarity = 7 }), "Astral")
	t.truthy(CompanionMath.matches(astral, "EggHatched", { rarity = 10 }), "lebih baik")
	local timeless = CompanionMath.questsFor(4)[1]
	t.eq(CompanionMath.matches(timeless, "EggGrabbed", { rarity = 8 }), false, "Void kurang")
	t.truthy(CompanionMath.matches(timeless, "EggGrabbed", { rarity = 9 }), "Timeless")

	t.eq(CompanionMath.add(19, grab, 1), 20, "tambah")
	t.eq(CompanionMath.add(20, grab, 5), 20, "cap target")
	t.eq(CompanionMath.count({ [grab.key] = 99 }, grab), 20, "count dibatasi")

	local progress = { [grab.key] = 20, [hatch.key] = 4 }
	t.eq(CompanionMath.isComplete(1, progress), false, "belum lengkap")
	progress[hatch.key] = 5
	t.eq(CompanionMath.isComplete(1, progress), true, "lengkap")

	local c = { stage = 1, progress = progress, claimed = {} }
	t.eq(CompanionMath.canClaim(c), true, "bisa klaim")
	c.claimed["1"] = true
	t.eq(CompanionMath.canClaim(c), false, "sudah diklaim")

	t.eq(CompanionMath.nextStage(1), 2, "next")
	t.eq(CompanionMath.nextStage(4), 4, "stage 4 tetap")

	t.near(CompanionMath.incomeBonus({ claimed = {} }), 0, 1e-9, "tanpa bonus")
	t.near(CompanionMath.incomeBonus({ claimed = { ["1"] = true } }), 0.05, 1e-9, "stage 1")
	t.near(
		CompanionMath.incomeBonus({ claimed = { ["1"] = true, ["2"] = true, ["3"] = true } }),
		0.15,
		1e-9,
		"stage 1-3"
	)
	t.near(
		CompanionMath.incomeBonus({
			claimed = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true },
		}),
		0.20,
		1e-9,
		"semua"
	)
	t.near(CompanionMath.speedMult({ claimed = { ["1"] = true } }), 1, 1e-9, "speed stage 1")
	t.near(CompanionMath.speedMult({ claimed = { ["2"] = true } }), 1.05, 1e-9, "speed stage 2")
	t.near(CompanionMath.scaleFor(4), 1.8, 1e-9, "skala")
end
