local EconomyConfig = require("../../src/shared/Config/EconomyConfig")
local LeaderboardMath = require("../../src/shared/Logic/LeaderboardMath")

return function(t)
	t.eq(LeaderboardMath.encode(0), 0, "encode 0")
	t.eq(LeaderboardMath.encode(-5), 0, "encode negatif")
	t.eq(LeaderboardMath.encode(9), 1e9, "encode 9 = 1e9")
	t.eq(LeaderboardMath.decode(0), 0, "decode 0")

	for _, x in { 1, 3.5, 45, 1234, 9.9e6, 1e12, 3.3e30, 1e100, 1e250 } do
		local back = LeaderboardMath.decode(LeaderboardMath.encode(x))
		t.truthy(math.abs(back - x) / x < 1e-6, "round trip " .. x)
	end

	local prev = -1
	local mono = true
	for _, x in { 0, 1, 2, 10, 99, 1e3, 1e6, 1e9, 1e20, 1e100, 1e299 } do
		local v = LeaderboardMath.encode(x)
		if v <= prev and x > 0 then
			mono = false
		end
		prev = v
	end
	t.truthy(mono, "monoton naik")

	local clamped = LeaderboardMath.encode(1e308)
	t.eq(clamped, LeaderboardMath.encode(1e300), "klem 1e300")
	t.truthy(clamped < 2 ^ 53, "muat integer eksak")

	local rows = {}
	for i = 1, 15 do
		table.insert(rows, { value = i % 5, userId = i })
	end
	local top = LeaderboardMath.rank(rows, 10)
	t.eq(#top, 10, "maks 10 baris")
	t.eq(top[1].value, 4, "nilai terbesar dulu")
	t.eq(top[1].userId, 4, "seri: userId kecil dulu")
	t.eq(#rows, 15, "input tidak diubah")

	t.truthy(LeaderboardMath.shouldWrite(nil, 5, 0.01), "tulis pertama")
	t.truthy(not LeaderboardMath.shouldWrite(nil, 0, 0.01), "nol tidak ditulis")
	t.truthy(not LeaderboardMath.shouldWrite(100, 100.5, 0.01), "perubahan < 1%")
	t.truthy(LeaderboardMath.shouldWrite(100, 101, 0.01), "perubahan >= 1%")
	t.truthy(LeaderboardMath.shouldWrite(100, 50, 0.01), "turun juga ditulis")

	t.eq(EconomyConfig.friendBoost(0), 0, "0 teman")
	t.near(EconomyConfig.friendBoost(1), 0.1, 1e-9, "1 teman")
	t.near(EconomyConfig.friendBoost(3), 0.3, 1e-9, "3 teman")
	t.near(EconomyConfig.friendBoost(5), 0.5, 1e-9, "5 teman")
	t.near(EconomyConfig.friendBoost(20), 0.5, 1e-9, "maks +50%")
	t.eq(EconomyConfig.friendBoost(-2), 0, "negatif")
end
