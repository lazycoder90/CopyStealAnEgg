--!nonstrict
-- Skenario uji Sell: total sesuai PetMath/SellMath, pet aktif/terkunci dan telur beku terlindungi,
-- uid ganda/tidak dikenal diabaikan, jual telur placed menghapus model, uang bertambah sekali.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Sell")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local PetMath = require(Shared.Logic.PetMath)

local InvariantChecker = require(Server.Systems.InvariantChecker)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local PetService = require(Server.Services.PetService)
local SellService = require(Server.Services.SellService)
local StateReplicator = require(Server.Services.StateReplicator)

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local SPECIES = "moss_pup"

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)

	local function addPet(kg: number, eq: boolean?, lock: boolean?)
		local uid = newUid()
		PetService.addPet(userId, uid, {
			id = SPECIES,
			kg = kg,
			g = "M",
			muts = {},
			eq = eq == true,
			lock = lock == true,
			t = 0,
		})
		return uid
	end
	local function addEgg(kg: number, loc: string, x: number?)
		local uid = newUid()
		data.eggs[uid] = {
			id = SPECIES,
			kg = kg,
			muts = { "Pearl" },
			growTotal = 100,
			progress = 10,
			loc = loc,
			pos = if loc == "placed" then { x = x or 0, z = -5 } else nil,
			t = 0,
		}
		StateReplicator.set(userId, `eggs.{uid}`, data.eggs[uid])
		if loc == "placed" then
			GrowthService.ensureModel(userId, uid)
		end
		return uid
	end

	-- ===== Pet =====
	local p1, p2 = addPet(2), addPet(5)
	local pEq = addPet(1, true)
	local pLock = addPet(1, false, true)
	local cash0 = data.cash
	local expected = PetMath.sellPetValue(SPECIES, 2, {}) + PetMath.sellPetValue(SPECIES, 5, {})

	local ok, count, total =
		SellService.sell(userId, "pets", { p1, p2, pEq, pLock, "tidak_ada", p1, 42 })
	T.check("jual pet berhasil", ok == true)
	T.check("jumlah terjual 2 (aktif/terkunci/tidak dikenal/ganda diabaikan)", count == 2, count)
	T.check("total sesuai PetMath", math.abs(total - expected) < 1e-6, `{total} vs {expected}`)
	T.check("uang naik tepat total", math.abs(data.cash - (cash0 + expected)) < 1e-6, data.cash)
	T.check("pet terjual hilang", data.pets[p1] == nil and data.pets[p2] == nil)
	T.check("pet aktif dan terkunci tetap ada", data.pets[pEq] ~= nil and data.pets[pLock] ~= nil)

	local cashBefore = data.cash
	ok, count = SellService.sell(userId, "pets", { pEq, pLock })
	T.check("jual hanya yang terlindungi: ditolak", ok == false and count == 0)
	T.check("uang tidak berubah", data.cash == cashBefore)
	ok, count = SellService.sell(userId, "pets", { p1 })
	T.check("jual ulang uid yang sudah hilang: 0", ok == false and count == 0)
	ok = SellService.sell(userId, "gems", { p1 })
	T.check("jenis tidak valid ditolak", ok == false)

	-- ===== Telur =====
	local e1 = addEgg(3, "pocket")
	local e2 = addEgg(4, "placed", -10)
	local e3 = addEgg(6, "placed", 10)
	T.check("model telur e2 ada sebelum dijual", GrowthService.getModel(userId, e2) ~= nil)

	GrowthService.setFrozen(userId, e3, true)
	local expectedEggs = PetMath.sellEggValue(SPECIES, 3, { "Pearl" })
		+ PetMath.sellEggValue(SPECIES, 4, { "Pearl" })
	cashBefore = data.cash
	ok, count, total = SellService.sell(userId, "eggs", { e1, e2, e3, e1, "xx" })
	T.check("jual telur: 2 terjual (beku diabaikan)", ok == true and count == 2, count)
	T.check(
		"total telur sesuai PetMath",
		math.abs(total - expectedEggs) < 1e-6,
		`{total} vs {expectedEggs}`
	)
	T.check("uang naik sekali", math.abs(data.cash - (cashBefore + expectedEggs)) < 1e-6)
	T.check("telur pocket dan placed terjual hilang", data.eggs[e1] == nil and data.eggs[e2] == nil)
	T.check("model telur terjual dihapus", GrowthService.getModel(userId, e2) == nil)
	T.check("telur beku tetap ada", data.eggs[e3] ~= nil)
	GrowthService.setFrozen(userId, e3, false)

	ok, count = SellService.sell(userId, "eggs", { e3 })
	T.check("telur tidak beku lagi bisa dijual", ok == true and count == 1)
	T.check("model e3 dihapus", GrowthService.getModel(userId, e3) == nil)

	-- Hook TestBridge
	local bridge = game:GetService("ServerStorage")[require(Shared.Types).Names.TestBridge]
	local p3 = addPet(3)
	local res = bridge:Invoke("sell.sell", userId, "pets", { p3 })
	T.check("hook sell.sell", res.ok and res.result.ok and res.result.count == 1, res.error)

	-- Bersih
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
	local eggsLeft = 0
	for _ in data.eggs do
		eggsLeft += 1
	end
	T.check("tidak ada telur tersisa", eggsLeft == 0, eggsLeft)
end
