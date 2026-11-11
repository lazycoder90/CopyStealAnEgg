local Creatures = require("../../src/shared/Config/Creatures")
local FuseLogic = require("../../src/shared/Logic/FuseLogic")
local PetMath = require("../../src/shared/Logic/PetMath")
local RNG = require("../../src/shared/Logic/RNG")

local function trio(id, kg, muts)
	return {
		{ id = id, kg = kg, muts = table.clone(muts) },
		{ id = id, kg = kg, muts = table.clone(muts) },
		{ id = id, kg = kg, muts = table.clone(muts) },
	}
end

return function(t)
	local base = Creatures.get("moss_pup").baseKg
	local ok = FuseLogic.canFuse(trio("moss_pup", base, {}))
	t.eq(ok, true, "canFuse ok")
	local bad, reason = FuseLogic.canFuse({ { id = "moss_pup", kg = 1, muts = {} } })
	t.eq(bad, false, "canFuse kurang")
	t.truthy(type(reason) == "string", "ada alasan")
	local mixed = trio("moss_pup", 1, {})
	mixed[3].id = "pebble_chick"
	t.eq((FuseLogic.canFuse(mixed)), false, "canFuse beda spesies")

	-- luck
	t.eq(FuseLogic.luck(trio("moss_pup", base, {})), 0, "luck rata-rata = 0")
	t.near(FuseLogic.luck(trio("moss_pup", base, { "Pearl", "Amber" })), 1.5, 1e-9, "luck mutasi")
	t.eq(FuseLogic.luck(trio("moss_pup", base, { "Prism", "Starlit" })), 2, "luck clamp 2")
	t.eq(FuseLogic.luck(trio("moss_pup", base * 0.3, {})), 0, "luck clamp 0")

	-- cost
	t.near(FuseLogic.cost(trio("moss_pup", base, {})), 135, 1e-9, "cost 10x income")
	t.near(
		FuseLogic.cost(trio("moss_pup", base, {})),
		10 * 3 * PetMath.petIncome("moss_pup", base, {}),
		1e-9,
		"cost = 10 * sum"
	)

	-- Probabilitas, luck 0
	local r = RNG.new(77)
	local N = 20000
	local up, prism, sameKgOk = 0, 0, true
	local pets = trio("moss_pup", base, {})
	for _ = 1, N do
		local res = FuseLogic.fuse(r, pets)
		if res.upgraded then
			up += 1
			if res.id ~= "clover_bunny" or res.kg ~= Creatures.get("clover_bunny").baseKg then
				sameKgOk = false
			end
		elseif res.id ~= "moss_pup" or math.abs(res.kg - base * 3 * 0.6) > 1e-9 then
			sameKgOk = false
		end
		if res.prism then
			prism += 1
		end
	end
	t.truthy(sameKgOk, "hasil/kg benar")
	t.near(up / N, 0.30, 0.03, "upgrade 30%")
	t.near(prism / N, 0.02, 0.03, "prism 2%")

	-- Luck 2 (3x Starlit+Amber... clamp 2): upgrade 50%, prism 8%
	local strong = trio("moss_pup", base, { "Pearl", "Amber", "Starlit" })
	t.eq(FuseLogic.luck(strong), 2, "luck 2")
	up, prism = 0, 0
	for _ = 1, N do
		local res = FuseLogic.fuse(r, strong)
		if res.upgraded then
			up += 1
		end
		if res.prism then
			prism += 1
		end
	end
	t.near(up / N, 0.50, 0.03, "upgrade 50% luck 2")
	t.near(prism / N, 0, 0.001, "prism tak bisa (mutasi penuh)")

	-- Mutasi: union, unik, urutan, maks 3
	local mix = {
		{ id = "moss_pup", kg = base, muts = { "Amber" } },
		{ id = "moss_pup", kg = base, muts = { "Pearl", "Amber" } },
		{ id = "moss_pup", kg = base, muts = { "Prism" } },
	}
	local res = FuseLogic.fuse(r, mix)
	t.eq(table.concat(res.muts, ","), "Pearl,Amber,Prism", "union urut")
	t.eq(res.prism, false, "prism sudah ada tidak dihitung baru")

	-- Prism ditambahkan saat ada ruang
	local gotPrism = false
	for _ = 1, 2000 do
		local x = FuseLogic.fuse(r, trio("moss_pup", base, { "Pearl" }))
		if x.prism then
			gotPrism = table.find(x.muts, "Prism") ~= nil and table.find(x.muts, "Pearl") ~= nil
			break
		end
	end
	t.truthy(gotPrism, "Prism ditambahkan ke union")

	-- Batas rantai: slot 8 -> slot 1 zona berikut; zona 12 slot 8 tetap
	local griffin = trio(
		"sunpetal_griffin",
		Creatures.get("sunpetal_griffin").baseKg,
		{ "Pearl", "Amber", "Starlit" }
	)
	local crossed = false
	for _ = 1, 200 do
		local x = FuseLogic.fuse(r, griffin)
		if x.upgraded then
			crossed = x.id == "reed_newt"
			break
		end
	end
	t.truthy(crossed, "slot 8 -> slot 1 zona 2")
	local last = trio("last_ember", 10, { "Pearl", "Amber", "Starlit" })
	local stays = true
	for _ = 1, 500 do
		local x = FuseLogic.fuse(r, last)
		if x.upgraded or x.id ~= "last_ember" then
			stays = false
		end
	end
	t.truthy(stays, "ujung rantai tetap")
end
