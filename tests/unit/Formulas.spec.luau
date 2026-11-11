local F = require("../../src/shared/Logic/Formulas")

return function(t)
	-- walkSpeed: nilai acuan dari docs/PLAN.md §3.6
	t.near(F.walkSpeed(10), 18.7, 0.1, "walk 10")
	t.near(F.walkSpeed(170e3), 54, 0.5, "walk 170K")
	t.near(F.walkSpeed(7e9), 95.6, 0.5, "walk 7B")
	t.near(F.walkSpeed(1e15), 142, 0.5, "walk 1Qa")
	t.eq(F.walkSpeed(1e60), 170, "walk clamp atas")
	t.eq(F.walkSpeed(0), 16, "walk clamp bawah")

	local prev = 0
	local monotone = true
	for e = 0, 40 do
		local w = F.walkSpeed(10 ^ e)
		if w < prev then
			monotone = false
		end
		prev = w
	end
	t.truthy(monotone, "walkSpeed monoton")

	-- Sprint Wheel
	t.eq(F.wheelGainPerStep(1), 2, "gain L1")
	t.eq(F.wheelGainPerStep(2), 4, "gain L2")
	t.eq(F.wheelGainPerStep(3), 6, "gain L3")
	t.eq(F.wheelGainPerStep(5), 19, "gain L5")
	t.near(F.wheelGainPerStep(14), 2900, 150, "gain L14 ~2.9K")
	t.eq(F.wheelUpgradePrice(1), 500, "price L1")
	t.eq(F.wheelUpgradePrice(5), 40500, "price L5")

	-- Offline: 1 jam income per hari offline
	t.eq(F.offlinePerDay(100), 360000, "offline/hari")
	t.eq(F.offlineEarned(100, 86400, 86400), 360000, "offline 24 jam")
	t.eq(F.offlineEarned(100, 200000, 86400), 360000, "offline kena cap")
	t.eq(F.offlineEarned(100, -5, 86400), 0, "offline negatif")

	-- Sell & mutasi
	t.eq(F.sellEggValue(10), 800, "sell telur")
	t.eq(F.sellPetValue(10), 1000, "sell pet")
	t.eq(F.mutationMult({}), 1, "mut kosong")
	t.eq(F.mutationMult({ 1.5, 2 }), 2.5, "Pearl+Amber")
	t.eq(F.effectiveSpeed(100, 2, true, false), 400, "effective speed")
end
