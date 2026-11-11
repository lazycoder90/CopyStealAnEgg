local Formulas = require("../../src/shared/Logic/Formulas")
local OfflineMath = require("../../src/shared/Logic/OfflineMath")

return function(t)
	t.eq(OfflineMath.capSeconds(1), 86400, "cap 24 jam")
	t.eq(OfflineMath.capSeconds(7), 86400, "pen 7 tanpa bonus")
	t.eq(OfflineMath.capSeconds(8), 129600, "pen 8 = 36 jam")
	t.eq(OfflineMath.capSeconds(8, 2), 259200, "VIP x2")

	t.eq(OfflineMath.elapsed(1000, 0, 86400), 0, "lastOnline 0 = tanpa hitungan")
	t.eq(OfflineMath.elapsed(1000, 400, 86400), 600, "selisih biasa")
	t.eq(OfflineMath.elapsed(1000, 2000, 86400), 0, "jam mundur -> 0")
	t.eq(OfflineMath.elapsed(1e9, 1, 86400), 86400, "dijepit ke cap")

	t.eq(OfflineMath.advanceEgg(100, 1000, 300), 400, "telur maju")
	t.eq(OfflineMath.advanceEgg(900, 1000, 300), 1000, "telur dijepit")

	t.truthy(OfflineMath.shouldShowBanner(10, 60), "banner 60 dtk")
	t.truthy(not OfflineMath.shouldShowBanner(10, 59), "tanpa banner < 60 dtk")
	t.truthy(not OfflineMath.shouldShowBanner(0, 5000), "tanpa banner tanpa uang")

	local cap = OfflineMath.capSeconds(1)
	t.near(Formulas.offlineEarned(3, 7200, cap), 900, 1e-9, "2 jam x $3/s")
	t.near(Formulas.offlineEarned(3, 1e9, cap), 10800, 1e-9, "cap 24 jam")
end
