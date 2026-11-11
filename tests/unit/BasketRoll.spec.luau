local BasketRoll = require("../../src/shared/Logic/BasketRoll")
local EconomyConfig = require("../../src/shared/Config/EconomyConfig")
local RNG = require("../../src/shared/Logic/RNG")

return function(t)
	local rng = RNG.new(12345)
	local counts = { cash = 0, speed = 0, growth = 0, luck = 0 }
	local N = 5000
	for _ = 1, N do
		local kind = BasketRoll.roll(rng)
		counts[kind] += 1
	end
	local total = 0
	for _, reward in EconomyConfig.basket.rewards do
		total += reward.weight
	end
	for _, reward in EconomyConfig.basket.rewards do
		t.near(counts[reward.kind] / N, reward.weight / total, 0.03, "bobot " .. reward.kind)
	end

	local a, b = RNG.new(9), RNG.new(9)
	local same = true
	for _ = 1, 100 do
		if BasketRoll.roll(a) ~= BasketRoll.roll(b) then
			same = false
		end
	end
	t.truthy(same, "deterministik")
	t.eq(total, 100, "bobot total 100")
end
