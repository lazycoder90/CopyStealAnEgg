--!strict
-- Undian hadiah Free Basket. Murni: bobot dari EconomyConfig, RNG dari pemanggil.

local EconomyConfig = require("../Config/EconomyConfig")
local RNG = require("./RNG")

local BasketRoll = {}

local function weights(): { number }
	local list = {}
	for _, reward in EconomyConfig.basket.rewards do
		table.insert(list, reward.weight)
	end
	return list
end

-- Mengembalikan "cash" | "speed" | "growth" | "luck".
function BasketRoll.roll(rng: RNG.RNG): string
	local index = rng:weighted(weights())
	return EconomyConfig.basket.rewards[index].kind
end

return BasketRoll
