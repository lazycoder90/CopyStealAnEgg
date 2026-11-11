local Creatures = require("../../src/shared/Config/Creatures")
local Formulas = require("../../src/shared/Logic/Formulas")
local PetMath = require("../../src/shared/Logic/PetMath")

return function(t)
	local c = Creatures.get("moss_pup")
	t.near(PetMath.petIncome("moss_pup", c.baseKg, {}), 4.5, 1e-9, "income dasar")
	t.near(
		PetMath.petIncome("moss_pup", c.baseKg, { "Pearl", "Amber" }),
		4.5 * 2.5,
		1e-9,
		"income + mutasi"
	)
	local w = Formulas.weightMult(5, c.baseKg)
	t.near(PetMath.petIncome("moss_pup", 5, { "Pearl" }), 4.5 * w * 1.5, 1e-9, "income + berat")
	t.eq(PetMath.eggProjectedIncome, PetMath.petIncome, "alias")
	t.near(PetMath.sellEggValue("moss_pup", c.baseKg, {}), 360, 1e-9, "sell egg 80x")
	t.near(PetMath.sellPetValue("moss_pup", c.baseKg, {}), 450, 1e-9, "sell pet 100x")
end
