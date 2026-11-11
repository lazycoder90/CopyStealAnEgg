--!strict
-- Roll berat (docs/PLAN.md §3.4). Deterministik untuk rng yang sama.

local RNG = require("./RNG")

local WeightRoll = {}

WeightRoll.heftyChance = 0.01

function WeightRoll.roll(rng: RNG.RNG, baseKg: number): number
	local kg = baseKg * math.clamp(math.exp(rng:normal() * 0.3), 0.6, 2.5)
	if rng:chance(WeightRoll.heftyChance) then
		kg *= rng:range(2.5, 4)
	end
	return math.floor(kg * 100 + 0.5) / 100
end

return WeightRoll
