local RNG = require("../../src/shared/Logic/RNG")
local WeightRoll = require("../../src/shared/Logic/WeightRoll")

return function(t)
	local a, b = RNG.new(42), RNG.new(42)
	local same = true
	for _ = 1, 100 do
		if WeightRoll.roll(a, 6) ~= WeightRoll.roll(b, 6) then
			same = false
		end
	end
	t.truthy(same, "deterministik")

	local r = RNG.new(7)
	local sum, minV, maxV, hefty = 0, math.huge, 0, 0
	local N = 20000
	local roundedOk = true
	for _ = 1, N do
		local kg = WeightRoll.roll(r, 10)
		sum += kg
		minV = math.min(minV, kg)
		maxV = math.max(maxV, kg)
		if kg > 25.01 then
			hefty += 1
		end
		if math.abs(kg * 100 - math.floor(kg * 100 + 0.5)) > 1e-6 then
			roundedOk = false
		end
	end
	t.truthy(roundedOk, "2 desimal")
	t.truthy(minV >= 6 - 0.01, "batas bawah 0.6x")
	t.truthy(maxV <= 100.01, "batas atas 2.5x*4")
	t.truthy(hefty / N > 0.003 and hefty / N < 0.02, "Hefty ~1%")
	t.near(sum / N / 10, 1.06, 0.12, "rata-rata ~1.05x")
end
