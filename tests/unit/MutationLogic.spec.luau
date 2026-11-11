local Mutations = require("../../src/shared/Config/Mutations")
local MutationLogic = require("../../src/shared/Logic/MutationLogic")
local RNG = require("../../src/shared/Logic/RNG")

return function(t)
	t.eq(MutationLogic.mult({}), 1, "mult kosong")
	t.eq(MutationLogic.mult({ "Pearl" }), 1.5, "mult Pearl")
	t.eq(MutationLogic.mult({ "Pearl", "Amber" }), 2.5, "mult ditambah")
	t.eq(MutationLogic.mult({ "Pearl", "Nope" }), 1.5, "nama tak dikenal diabaikan")
	t.eq(MutationLogic.mult({ "Pearl", "Amber", "Prism" }), 7.5, "mult 3 mutasi")

	t.eq(MutationLogic.canAdd({}, "Pearl"), true, "canAdd")
	t.eq(MutationLogic.canAdd({ "Pearl" }, "Pearl"), false, "duplikat")
	t.eq(MutationLogic.canAdd({}, "Nope"), false, "tak dikenal")
	t.eq(MutationLogic.canAdd({ "Pearl", "Amber", "Starlit" }, "Prism"), false, "penuh")

	local base = { "Pearl" }
	local added = MutationLogic.add(base, "Amber")
	t.eq(#base, 1, "add tidak mengubah asal")
	t.eq(MutationLogic.format(added), "Pearl + Amber", "add")
	t.eq(MutationLogic.format(MutationLogic.add(base, "Pearl")), "Pearl", "add duplikat = salinan")
	t.truthy(MutationLogic.add(base, "Pearl") ~= base, "add mengembalikan salinan")
	t.eq(MutationLogic.format({}), "", "format kosong")

	-- rollOnHatch: frekuensi mendekati hatchChance
	local r = RNG.new(11)
	local N = 100000
	local counts = { Pearl = 0, Amber = 0, Starlit = 0 }
	local valid = true
	for _ = 1, N do
		local muts = MutationLogic.rollOnHatch(r)
		if #muts > 3 then
			valid = false
		end
		for _, m in muts do
			if counts[m] == nil then
				valid = false
			else
				counts[m] += 1
			end
		end
	end
	t.truthy(valid, "hanya Pearl/Amber/Starlit")
	t.near(counts.Pearl / N, Mutations.list.Pearl.hatchChance, 0.004, "Pearl 4%")
	t.near(counts.Amber / N, Mutations.list.Amber.hatchChance, 0.003, "Amber 1.5%")
	t.near(counts.Starlit / N, Mutations.list.Starlit.hatchChance, 0.002, "Starlit 0.4%")

	local lucky = 0
	for _ = 1, 20000 do
		if table.find(MutationLogic.rollOnHatch(r, 2), "Pearl") then
			lucky += 1
		end
	end
	t.near(lucky / 20000, 0.08, 0.01, "luckMult 2 -> Pearl 8%")
end
