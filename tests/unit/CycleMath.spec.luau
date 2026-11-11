local CycleMath = require("../../src/shared/Logic/CycleMath")

return function(t)
	t.eq(CycleMath.duration("Day"), 240, "siang 240")
	t.eq(CycleMath.duration("Night"), 90, "malam 90")
	t.eq(CycleMath.other("Day"), "Night", "other")

	local state, remaining, entered = CycleMath.advance("Day", 10, 4)
	t.eq(state, "Day", "belum berganti")
	t.near(remaining, 6, 1e-9, "sisa")
	t.eq(#entered, 0, "tanpa pergantian")

	state, remaining, entered = CycleMath.advance("Day", 1, 3)
	t.eq(state, "Night", "berganti ke malam")
	t.near(remaining, 88, 1e-9, "sisa malam membawa sisa dt")
	t.eq(entered[1], "Night", "entered malam")

	state, remaining, entered = CycleMath.advance("Day", 5, 5)
	t.eq(state, "Night", "tepat 0 berganti")
	t.near(remaining, 90, 1e-9, "malam penuh")
	t.eq(#entered, 1, "satu pergantian")

	-- dt besar melewati beberapa fase: 240 + 90 + 240 + 10
	state, remaining, entered = CycleMath.advance("Day", 240, 580)
	t.eq(#entered, 3, "tiga pergantian")
	t.eq(state, "Night", "akhir malam")
	t.near(remaining, 80, 1e-9, "sisa akhir")

	t.near(CycleMath.darkness("Night", 90), 0, 1e-9, "awal malam masih terang")
	t.near(CycleMath.darkness("Night", 50), 1, 1e-9, "malam gelap penuh")
	t.near(CycleMath.darkness("Day", 240), 1, 1e-9, "awal siang masih gelap")
	t.near(CycleMath.darkness("Day", 100), 0, 1e-9, "siang terang")
	t.near(CycleMath.darkness("Night", 86), 0.5, 1e-9, "tengah ramp")
	t.near(CycleMath.clockTime(0), 14, 1e-9, "clock siang")
	t.near(CycleMath.clockTime(1), 0, 1e-9, "clock malam = 0")

	t.eq(CycleMath.format(259), "4m 19s", "format 259")
	t.eq(CycleMath.format(45.2), "46s", "format dibulatkan ke atas")
	t.eq(CycleMath.format(0), "0s", "format 0")
	t.eq(CycleMath.format(60), "1m 0s", "format 60")
	t.eq(CycleMath.formatClock(125), "2:05", "formatClock")

	t.eq(CycleMath.countdownLabel("Day", 9.2), "Night in 10", "label siang")
	t.eq(CycleMath.countdownLabel("Night", 1), "Day in 1", "label malam")
	t.eq(CycleMath.countdownLabel("Day", 11), nil, "belum waktunya")
	t.eq(CycleMath.countdownLabel("Day", 0), nil, "habis")
	t.eq(CycleMath.growthMultiplier("Night"), 30, "pengali malam")
	t.eq(CycleMath.growthMultiplier("Day"), nil, "tanpa pengali siang")
end
