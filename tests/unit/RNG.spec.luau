local RNG = require("../../src/shared/Logic/RNG")

return function(t)
	-- Deterministik untuk seed yang sama
	local a, b = RNG.new(1234), RNG.new(1234)
	local same = true
	for _ = 1, 100 do
		if a:next() ~= b:next() then
			same = false
		end
	end
	t.truthy(same, "seed sama -> urutan sama")
	t.truthy(RNG.new(1):next() ~= RNG.new(2):next(), "seed beda -> beda")

	local c = RNG.new(7)
	local first = c:next()
	c:reseed(7)
	t.eq(c:next(), first, "reseed")

	-- int dalam rentang inklusif dan semua nilai muncul
	local r = RNG.new(99)
	local seen = {}
	local inRange = true
	for _ = 1, 2000 do
		local v = r:int(3, 7)
		if v < 3 or v > 7 or v % 1 ~= 0 then
			inRange = false
		end
		seen[v] = true
	end
	t.truthy(inRange, "int dalam [3,7]")
	t.truthy(seen[3] and seen[7], "int mencakup ujung rentang")

	-- next di [0,1) dan range di [min,max)
	local ok = true
	for _ = 1, 5000 do
		local v = r:next()
		local w = r:range(2, 5)
		if v < 0 or v >= 1 or w < 2 or w >= 5 then
			ok = false
		end
	end
	t.truthy(ok, "next/range dalam batas")

	-- weighted ~ bobot (100k sampel, toleransi 2%)
	local weights = { 35, 25, 18, 14, 8 }
	local counts = { 0, 0, 0, 0, 0 }
	local N = 100000
	for _ = 1, N do
		local i = r:weighted(weights)
		counts[i] += 1
	end
	for i, w in weights do
		t.near(counts[i] / N, w / 100, 0.02, `weighted idx {i}`)
	end
	t.eq(RNG.new(5):weighted({ 0, 0, 5 }), 3, "weighted bobot nol tidak terpilih")
	t.eq(RNG.new(5):weighted({ 0, 0 }), 1, "weighted semua nol")

	-- chance
	local hits = 0
	for _ = 1, N do
		if r:chance(0.3) then
			hits += 1
		end
	end
	t.near(hits / N, 0.3, 0.02, "chance 0.3")

	-- normal: mean ~0, sd ~1
	local sum, sumSq = 0, 0
	for _ = 1, 20000 do
		local v = r:normal()
		sum += v
		sumSq += v * v
	end
	t.near(sum / 20000, 0, 0.05, "normal mean")
	t.near(sumSq / 20000, 1, 0.05, "normal var")

	-- shuffle: permutasi
	local list = RNG.new(3):shuffle({ 1, 2, 3, 4, 5, 6 })
	local total = 0
	for _, v in list do
		total += v
	end
	t.eq(total, 21, "shuffle mempertahankan isi")
end
