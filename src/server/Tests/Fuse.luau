--!nonstrict
-- Skenario uji Wave 3: Fuse Machine (syarat, biaya, hasil seed tetap, flag upgraded/prism, gabung mutasi).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Fuse")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local FuseLogic = require(Shared.Logic.FuseLogic)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)

local InvariantChecker = require(Server.Systems.InvariantChecker)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local FuseService = require(Server.Services.FuseService)
local PetService = require(Server.Services.PetService)

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function sameList(a, b): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	CurrencyService.set(userId, "cash", 1e12)

	local species = Creatures.get("moss_pup")
	local function give(id: string?, kg: number?, muts)
		local uid =
			bridge:Invoke("pets.give", userId, id or species.id, kg or species.baseKg).result
		if muts then
			DataService.getByUserId(userId).pets[uid].muts = muts
		end
		return uid
	end
	local function trio(muts1, muts2, muts3)
		return { give(nil, nil, muts1), give(nil, nil, muts2), give(nil, nil, muts3) }
	end
	local function listOf(uids)
		local out = {}
		for _, uid in uids do
			local p = DataService.getByUserId(userId).pets[uid]
			table.insert(out, { id = p.id, kg = p.kg, muts = table.clone(p.muts) })
		end
		return out
	end

	-- ===== penolakan =====
	local uids = trio({}, {}, {})
	local cashBefore = data.cash
	local countBefore = PetService.petCount(data)
	local ok2 = FuseService.fuse(userId, { uids[1], uids[2] })
	T.check("2 pet ditolak", ok2 == false)
	local okMixed = FuseService.fuse(userId, { uids[1], uids[2], give("pebble_chick", 1.2) })
	T.check("spesies berbeda ditolak", okMixed == false)
	local okDup = FuseService.fuse(userId, { uids[1], uids[2], uids[2] })
	T.check("uid ganda ditolak", okDup == false)
	local okMissing = FuseService.fuse(userId, { uids[1], uids[2], "tidakada1234567" })
	T.check("uid tidak ada ditolak", okMissing == false)

	PetService.equip(userId, uids[1])
	local okEq = FuseService.fuse(userId, uids)
	T.check("pet aktif ditolak", okEq == false)
	PetService.unequip(userId, uids[1])
	PetService.setLock(userId, uids[2], true)
	local okLock = FuseService.fuse(userId, uids)
	T.check("pet terkunci ditolak", okLock == false)
	PetService.setLock(userId, uids[2], false)
	T.check("penolakan tidak memotong cash", data.cash == cashBefore)
	T.check("penolakan tidak menghapus pet", PetService.petCount(data) == countBefore + 1) -- +1 pebble_chick

	local cost = FuseLogic.cost(listOf(uids))
	CurrencyService.set(userId, "cash", cost - 1)
	local okPoor = FuseService.fuse(userId, uids)
	T.check("cash kurang ditolak", okPoor == false)
	T.check("cash kurang: pet utuh", data.pets[uids[1]] ~= nil and data.pets[uids[3]] ~= nil)
	T.check("cash kurang: saldo utuh", data.cash == cost - 1)

	-- ===== hasil dengan seed tetap =====
	CurrencyService.set(userId, "cash", 1e12)
	local expected = FuseLogic.fuse(RNG.new(123), listOf(uids))
	local luck = FuseLogic.luck(listOf(uids))
	FuseService.setSeed(123)
	local pre = PetService.petCount(data)
	local ok, payload = FuseService.fuse(userId, uids)
	T.check("fuse berhasil", ok == true, payload)
	if ok then
		T.check("id sesuai FuseLogic", payload.speciesId == expected.id)
		T.check("kg sesuai FuseLogic", near(payload.kg, expected.kg, 1e-9))
		T.check("muts sesuai FuseLogic", sameList(payload.muts, expected.muts))
		T.check(
			"flag upgraded/prism sesuai",
			payload.upgraded == expected.upgraded and payload.prism == expected.prism
		)
		T.check(
			"pet bersih: 3 hilang",
			data.pets[uids[1]] == nil and data.pets[uids[2]] == nil and data.pets[uids[3]] == nil
		)
		T.check(
			"pet hasil ada, tidak aktif, tidak terkunci",
			data.pets[payload.petUid] ~= nil
				and data.pets[payload.petUid].eq == false
				and data.pets[payload.petUid].lock == false
		)
		T.check(
			"jumlah pet bersih -2",
			PetService.petCount(data) == pre - 2,
			PetService.petCount(data)
		)
		T.check("biaya dipotong", near(data.cash, 1e12 - cost, 1e-3), data.cash)
		T.check(
			"biaya = 10x income",
			near(cost, 10 * 3 * PetMath.petIncome(species.id, species.baseKg, {}), 1e-6)
		)
		T.check("index found ditandai", data.index.found[payload.speciesId] == true)
		T.check("luck 0 untuk pet standar", luck == 0)
		local shapeOk = type(payload.petUid) == "string"
			and type(payload.speciesId) == "string"
			and type(payload.name) == "string"
			and type(payload.rarity) == "number"
			and type(payload.muts) == "table"
			and type(payload.kg) == "number"
			and (payload.gender == "M" or payload.gender == "F")
			and type(payload.income) == "number"
			and type(payload.isNew) == "boolean"
			and type(payload.upgraded) == "boolean"
			and type(payload.prism) == "boolean"
		T.check("bentuk payload FuseResult", shapeOk)
		T.check(
			"income payload = PetMath",
			near(
				payload.income,
				PetMath.petIncome(payload.speciesId, payload.kg, payload.muts),
				1e-9
			)
		)
	end

	-- ===== upgraded dan prism: cari seed yang memicu =====
	local function findSeed(pred)
		local sample = {
			{ id = species.id, kg = species.baseKg, muts = {} },
			{ id = species.id, kg = species.baseKg, muts = {} },
			{ id = species.id, kg = species.baseKg, muts = {} },
		}
		for seed = 1, 20000 do
			local r = FuseLogic.fuse(RNG.new(seed), sample)
			if pred(r) then
				return seed
			end
		end
		return nil
	end
	local upSeed = findSeed(function(r)
		return r.upgraded and not r.prism
	end)
	local prismSeed = findSeed(function(r)
		return r.prism and not r.upgraded
	end)
	T.check("ada seed upgraded", upSeed ~= nil)
	T.check("ada seed prism", prismSeed ~= nil)
	if upSeed then
		local u = trio({}, {}, {})
		FuseService.setSeed(upSeed)
		local okU, pu = FuseService.fuse(userId, u)
		local nextId = Creatures.byZone[1][species.slot + 1].id
		T.check(
			"upgraded: spesies slot berikutnya",
			okU and pu.upgraded and pu.speciesId == nextId,
			okU and pu.speciesId
		)
		T.check(
			"upgraded: kg = baseKg target",
			okU and near(pu.kg, Creatures.get(nextId).baseKg, 1e-9)
		)
	end
	if prismSeed then
		local p = trio({}, {}, {})
		FuseService.setSeed(prismSeed)
		local okP, pp = FuseService.fuse(userId, p)
		T.check(
			"prism: Prism ada di muts",
			okP and pp.prism and table.find(pp.muts, "Prism") ~= nil
		)
		T.check("prism: spesies sama", okP and pp.speciesId == species.id)
		T.check("prism: kg = 0.6 x total", okP and near(pp.kg, species.baseKg * 3 * 0.6, 1e-9))
	end

	-- ===== mutasi digabung, maksimal 3 =====
	local m = trio({ "Pearl", "Amber" }, { "Starlit", "Moonlit" }, { "Orbital" })
	local mExpected = FuseLogic.fuse(RNG.new(55), listOf(m))
	FuseService.setSeed(55)
	local okM, pm = FuseService.fuse(userId, m)
	T.check("fuse dengan banyak mutasi berhasil", okM == true)
	T.check("mutasi gabungan maks 3", okM and #pm.muts <= 3, okM and #pm.muts)
	T.check(
		"mutasi gabungan = Pearl+Amber+Starlit",
		okM and sameList(pm.muts, { "Pearl", "Amber", "Starlit" }),
		okM and table.concat(pm.muts, ",")
	)
	T.check("hasil sama dengan FuseLogic", okM and sameList(pm.muts, mExpected.muts))

	-- ===== hook TestBridge =====
	local b = trio({}, {}, {})
	bridge:Invoke("fuse.seed", 9)
	local viaBridge = bridge:Invoke("fuse.fuse", userId, b).result
	T.check("hook fuse.fuse berjalan", viaBridge.ok == true)

	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))

	DataService.wipe(userId)
	T.wait(1.2)
end
