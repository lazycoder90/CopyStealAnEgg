local Layout = require("../../src/shared/Config/Layout")
local RNG = require("../../src/shared/Logic/RNG")
local StarwhaleConfig = require("../../src/shared/Config/StarwhaleConfig")
local StarwhaleMath = require("../../src/shared/Logic/StarwhaleMath")

local function dist(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2)
end

return function(t)
	-- Posisi telur aneh: valid untuk banyak seed dan zona.
	for zone = StarwhaleConfig.zoneMin, StarwhaleConfig.zoneMax do
		local whale = { 38, 16, (Layout.zoneZStart(zone) + Layout.zoneZEnd(zone)) / 2 }
		for seed = 1, 40 do
			local pos = StarwhaleMath.oddPositions(seed * 977 + zone, whale)
			local b = StarwhaleMath.laneBounds(whale[3])
			t.eq(#pos, 3, `3 telur zona {zone} seed {seed}`)
			local ok = true
			for i, p in pos do
				if dist(p, whale) > StarwhaleConfig.oddRadius + 1e-6 then
					ok = false
				end
				if dist(p, whale) < StarwhaleConfig.oddMinFromWhale - 1e-6 then
					ok = false
				end
				if p[1] < b.minX or p[1] > b.maxX or p[3] < b.minZ or p[3] > b.maxZ then
					ok = false
				end
				for j = i + 1, #pos do
					if dist(p, pos[j]) < StarwhaleConfig.oddSpacing - 1e-6 then
						ok = false
					end
				end
			end
			t.truthy(ok, `posisi valid zona {zone} seed {seed}`)
		end
	end

	-- Deterministik dan bergantung seed.
	local whale = { -35, 16, Layout.zoneZStart(4) + 150 }
	local a = StarwhaleMath.oddPositions(StarwhaleMath.oddSeed(1700000000, 42), whale)
	local b = StarwhaleMath.oddPositions(StarwhaleMath.oddSeed(1700000000, 42), whale)
	local c = StarwhaleMath.oddPositions(StarwhaleMath.oddSeed(1700000000, 43), whale)
	t.eq(a[1][1], b[1][1], "deterministik x")
	t.eq(a[3][3], b[3][3], "deterministik z")
	t.truthy(a[1][1] ~= c[1][1] or a[1][3] ~= c[1][3], "seed berbeda -> posisi berbeda")
	t.eq(a[1][2], StarwhaleConfig.oddY, "di lantai")

	-- Roll Stardust 1..4 dan semua nilai muncul.
	local rng = RNG.new(7)
	local seen = {}
	for _ = 1, 300 do
		local v = StarwhaleMath.stardustRoll(rng)
		t.truthy(v >= 1 and v <= 4 and v % 1 == 0, "roll 1..4")
		seen[v] = true
	end
	t.truthy(seen[1] and seen[2] and seen[3] and seen[4], "semua nilai roll muncul")

	-- Validasi penawaran.
	local placed = { loc = "placed", muts = {} }
	t.eq((StarwhaleMath.validateOffer("lucky", 15, nil)), true, "lucky 15 cukup")
	t.eq((StarwhaleMath.validateOffer("lucky", 14, nil)), false, "lucky 14 kurang")
	t.eq((StarwhaleMath.validateOffer("nope", 999, nil)), false, "penawaran tak dikenal")
	t.eq((StarwhaleMath.validateOffer("orbital", 40, placed, "e1")), true, "orbital valid")
	t.eq((StarwhaleMath.validateOffer("orbital", 39, placed, "e1")), false, "orbital kurang")
	t.eq((StarwhaleMath.validateOffer("orbital", 40, nil, nil)), false, "orbital tanpa target")
	t.eq(
		(StarwhaleMath.validateOffer("orbital", 40, { loc = "pocket", muts = {} }, "e1")),
		false,
		"pocket ditolak"
	)
	t.eq(
		(StarwhaleMath.validateOffer("orbital", 40, { loc = "placed", muts = { "Orbital" } }, "e1")),
		false,
		"duplikat ditolak"
	)
	t.eq(
		(
			StarwhaleMath.validateOffer(
				"orbital",
				40,
				{ loc = "placed", muts = { "Pearl", "Amber", "Starlit" } },
				"e1"
			)
		),
		false,
		"penuh ditolak"
	)
	t.eq(
		(
			StarwhaleMath.validateOffer(
				"orbital",
				40,
				{ loc = "placed", muts = {}, frozen = true },
				"e1"
			)
		),
		false,
		"beku ditolak"
	)
	t.eq(StarwhaleConfig.offerById.orbital.price, 40, "harga orbital")
	t.eq(StarwhaleConfig.offerById.growth.price, 25, "harga growth")

	-- Bearing: look -Z (0,-1); target di +X = kanan (+90), di -Z = depan (0), di +Z = belakang (180).
	t.near(StarwhaleMath.bearing(0, 0, 10, 0, 0, -1), 90, 1e-6, "kanan")
	t.near(StarwhaleMath.bearing(0, 0, 0, -10, 0, -1), 0, 1e-6, "depan")
	t.near(math.abs(StarwhaleMath.bearing(0, 0, 0, 10, 0, -1)), 180, 1e-6, "belakang")
	t.near(StarwhaleMath.bearing(0, 0, -10, 0, 0, -1), -90, 1e-6, "kiri")
	t.near(StarwhaleMath.bearing(0, 0, 0, 10, 0, 1), 0, 1e-6, "look +Z, target +Z = depan")

	-- Kedip: makin dekat makin cepat, dibatasi.
	t.truthy(
		StarwhaleMath.blinkInterval(10) < StarwhaleMath.blinkInterval(200),
		"dekat lebih cepat"
	)
	t.near(StarwhaleMath.blinkInterval(0), StarwhaleConfig.blinkFast, 1e-9, "min")
	t.near(StarwhaleMath.blinkInterval(9999), StarwhaleConfig.blinkSlow, 1e-9, "maks")
end
