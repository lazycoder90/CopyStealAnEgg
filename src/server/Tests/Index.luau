--!nonstrict
-- Skenario uji Wave 3: Pet Index (found saat hatch, claim, Claim All, bonus zona lengkap, unclaimed).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Index")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Creatures = require(Shared.Config.Creatures)
local IndexMath = require(Shared.Logic.IndexMath)

local InvariantChecker = require(Server.Systems.InvariantChecker)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local HatchService = require(Server.Services.HatchService)
local IncomeService = require(Server.Services.IncomeService)
local IndexService = require(Server.Services.IndexService)
local PetService = require(Server.Services.PetService)
local PlacementService = require(Server.Services.PlacementService)

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
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

	T.check(
		"index kosong di awal",
		next(data.index.found) == nil and next(data.index.claimed) == nil
	)
	T.check("unclaimed awal 0", IndexMath.unclaimedCount(data.index.found, data.index.claimed) == 0)
	T.check("96 spesies", IndexMath.totalSpecies() == 96)
	T.check("4 makhluk Limited statis", #CollectionConfig.index.limited == 4)
	for _, name in CollectionConfig.index.limited do
		local ok = true
		for _, c in Creatures.list do
			if c.name == name then
				ok = false
			end
		end
		T.check(`Limited '{name}' bukan makhluk yang bisa didapat`, ok)
	end

	-- ===== found ditandai saat hatch =====
	local zone1 = Creatures.byZone[1]
	local pebble = zone1[1]
	local eggUid = PlacementService.insert(userId, {
		uid = "idxegg1",
		id = pebble.id,
		kg = pebble.baseKg,
		muts = {},
		growTotal = 10,
		progress = 0,
	}, 12, -10)
	bridge:Invoke("growth.advance", userId, eggUid, 1000)
	local ok, payload = HatchService.hatch(userId, eggUid)
	T.check("hatch berhasil", ok == true, payload)
	T.check("hatch isNew", ok and payload.isNew == true)
	T.check("found ditandai saat hatch", data.index.found[pebble.id] == true)
	T.check(
		"unclaimed = 1 setelah hatch",
		IndexMath.unclaimedCount(data.index.found, data.index.claimed) == 1
	)
	if ok then
		PetService.unequip(userId, payload.petUid) -- hindari income yang mengubah saldo
	end

	-- ===== claim =====
	local rejected = bridge:Invoke("index.claim", userId, "moss_pup").result
	T.check("claim spesies belum ditemukan ditolak", rejected.ok == false)
	T.check(
		"claim id asing ditolak",
		bridge:Invoke("index.claim", userId, "bukan_spesies").result.ok == false
	)

	CurrencyService.set(userId, "cash", 0)
	CurrencyService.set(userId, "speedBase", 10)
	local expectCash, expectSpeed = IndexMath.rewards(pebble.id)
	T.check("reward cash = baseIncome x 120", near(expectCash, pebble.baseIncome * 120, 1e-9))
	local claimed, cash, speed = IndexService.claim(userId, pebble.id)
	T.check("claim berhasil", claimed == true)
	T.check("cash bertambah sesuai reward", near(data.cash, expectCash, 1e-6), data.cash)
	T.check("speedBase bertambah sesuai reward", data.speedBase == 10 + expectSpeed, data.speedBase)
	T.check("claim mengembalikan reward", cash == expectCash and speed == expectSpeed)
	T.check("claimed ditandai", data.index.claimed[pebble.id] == true)
	local again = IndexService.claim(userId, pebble.id)
	T.check("claim dua kali ditolak", again == false)
	T.check("claim dua kali tidak menambah cash", near(data.cash, expectCash, 1e-6))
	T.check(
		"unclaimed = 0 setelah claim",
		IndexMath.unclaimedCount(data.index.found, data.index.claimed) == 0
	)
	T.check(
		"Claim All tanpa isi ditolak",
		bridge:Invoke("index.claimAll", userId).result.ok == false
	)

	-- ===== bonus zona lengkap +2% =====
	local petUid = bridge:Invoke("pets.give", userId, "sunpetal_griffin", 520).result
	PetService.equip(userId, petUid)
	local before = IncomeService.compute(userId, data)
	T.check("income sebelum > 0", before > 0, before)

	local newZones = IndexService.evaluate(userId)
	T.check("belum ada zona baru lengkap", #newZones == 0)
	for i = 2, 8 do
		data.index.found[zone1[i].id] = true -- 7 spesies tambahan (spesies 1 sudah ditemukan)
	end
	T.check(
		"unclaimed = 7 sebelum evaluasi",
		IndexMath.unclaimedCount(data.index.found, data.index.claimed) == 7
	)
	local noBonusYet = IncomeService.compute(userId, data)
	T.check("income sama sebelum evaluasi", near(noBonusYet, before, 1e-9))
	newZones = IndexService.evaluate(userId)
	T.check("zona 1 baru lengkap", #newZones == 1 and newZones[1] == 1)
	T.check("zoneBonus['1'] tersimpan", data.index.zoneBonus["1"] == true)
	local after = IncomeService.compute(userId, data)
	-- Asumsi: tanpa bonus aditif lain (solo, tanpa teman) sehingga selisih tepat +2%.
	T.check("income naik tepat +2%", near(after / before, 1.02, 1e-9), after / before)
	T.check("evaluasi kedua tidak menambah lagi", #IndexService.evaluate(userId) == 0)
	T.check(
		"income tetap setelah evaluasi ulang",
		near(IncomeService.compute(userId, data), after, 1e-9)
	)

	-- ===== Claim All =====
	CurrencyService.set(userId, "cash", 0)
	CurrencyService.set(userId, "speedBase", 10)
	local wantCash, wantSpeed = 0, 0
	for i = 2, 8 do
		local c, s = IndexMath.rewards(zone1[i].id)
		wantCash += c
		wantSpeed += s
	end
	local res = bridge:Invoke("index.claimAll", userId).result
	T.check("Claim All berhasil", res.ok == true and res.count == 7, res.count)
	T.check("Claim All cash = jumlah reward", near(data.cash, wantCash, 1e-6), data.cash)
	T.check("Claim All speed = jumlah reward", data.speedBase == 10 + wantSpeed)
	T.check(
		"unclaimed 0 setelah Claim All",
		IndexMath.unclaimedCount(data.index.found, data.index.claimed) == 0
	)
	T.check("Claim All kedua ditolak", bridge:Invoke("index.claimAll", userId).result.ok == false)

	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))

	-- ===== rejoin: zoneBonus tetap berlaku =====
	DataService.simulateRejoin(userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	local sum = 0
	for _, pet in data.pets do
		if pet.eq then
			sum += PetService.petIncome(pet)
		end
	end
	if data.index.zoneBonus["1"] and sum > 0 then
		T.check(
			"bonus zona tetap berlaku setelah rejoin",
			near(IncomeService.compute(userId, data), sum * 1.02, 1e-6)
		)
	end

	DataService.wipe(userId)
	T.wait(1.2)
end
