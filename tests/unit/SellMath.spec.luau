local Creatures = require("../../src/shared/Config/Creatures")
local PetMath = require("../../src/shared/Logic/PetMath")
local SellMath = require("../../src/shared/Logic/SellMath")

return function(t)
	local c = Creatures.get("moss_pup")
	t.near(SellMath.eggValue("moss_pup", c.baseKg, {}), 360, 1e-9, "egg 80x")
	t.near(SellMath.petValue("moss_pup", c.baseKg, {}), 450, 1e-9, "pet 100x")
	t.near(
		SellMath.total(
			"pets",
			{ { id = "moss_pup", kg = c.baseKg, muts = {} }, { id = "moss_pup", kg = c.baseKg } }
		),
		900,
		1e-9,
		"total pets"
	)
	t.near(
		SellMath.total("eggs", { { id = "moss_pup", kg = c.baseKg, muts = { "Pearl" } } }),
		PetMath.sellEggValue("moss_pup", c.baseKg, { "Pearl" }),
		1e-9,
		"total egg mutasi"
	)
	t.eq(SellMath.total("eggs", {}), 0, "total kosong")

	-- filter
	t.eq(SellMath.petSellable({ eq = false, lock = false }), true, "pet biasa")
	t.eq(SellMath.petSellable({ eq = true, lock = false }), false, "pet aktif")
	t.eq(SellMath.petSellable({ eq = false, lock = true }), false, "pet terkunci")
	t.eq(SellMath.eggSellable({ loc = "pocket" }, false), true, "telur kantong")
	t.eq(SellMath.eggSellable({ loc = "placed" }, false), true, "telur placed")
	t.eq(SellMath.eggSellable({ loc = "placed" }, true), false, "telur beku")
	t.eq(SellMath.eggSellable(nil, false), false, "telur nil")

	local pets = {
		a = { id = "moss_pup", kg = 5, muts = {}, eq = false, lock = false },
		b = { id = "moss_pup", kg = 1, muts = {}, eq = true, lock = false },
		c = { id = "moss_pup", kg = 3, muts = {}, eq = false, lock = true },
		d = { id = "moss_pup", kg = 2, muts = { "Pearl" }, eq = false, lock = false },
		e = { id = "tidak_ada", kg = 2, muts = {}, eq = false, lock = false },
	}
	local list = SellMath.list("pets", pets)
	t.eq(#list, 2, "list pet: hanya a dan d")

	SellMath.sort(list, "weight", false)
	t.eq(list[1].uid, "a", "weight desc")
	SellMath.sort(list, "weight", true)
	t.eq(list[1].uid, "d", "weight asc")
	SellMath.sort(list, "value", false)
	t.truthy(list[1].value >= list[2].value, "value desc")

	local eggs = {
		x = { id = "moss_pup", kg = 1, muts = {}, loc = "pocket" },
		y = { id = "moss_pup", kg = 1, muts = {}, loc = "placed" },
	}
	local frozen = function(uid)
		return uid == "y"
	end
	t.eq(#SellMath.list("eggs", eggs, frozen), 1, "telur beku dikeluarkan")
	t.eq(#SellMath.list("eggs", eggs), 2, "tanpa isFrozen")

	local sel = { a = true }
	local sum, count = SellMath.selectedTotals(SellMath.list("pets", pets), sel)
	t.eq(count, 1, "jumlah terpilih")
	t.near(sum, SellMath.petValue("moss_pup", 5, {}), 1e-9, "total terpilih")
	t.eq(SellMath.hasValuable(SellMath.list("pets", pets), sel, 6), false, "tidak ada valuable")
	t.eq(SellMath.hasValuable(SellMath.list("pets", pets), sel, 1), true, "ada valuable rarity>=1")

	t.eq(SellMath.matches("Moss Pup", "moss"), true, "cari substring")
	t.eq(SellMath.matches("Moss Pup", ""), true, "cari kosong")
	t.eq(SellMath.matches("Moss Pup", "zzz"), false, "cari tak cocok")
end
