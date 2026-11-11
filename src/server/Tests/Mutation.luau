--!nonstrict
-- Skenario uji Wave 3: mutasi NPC (harga, sukses/gagal, aturan canAdd, telur tidak valid, TTL pilihan).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Mutation")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)
local Types = require(Shared.Types)

local InvariantChecker = require(Server.Systems.InvariantChecker)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local MutationService = require(Server.Services.MutationService)
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

	local species = Creatures.get("clover_bunny")
	local function placeEgg(uid: string, lx: number, lz: number)
		return PlacementService.insert(userId, {
			uid = uid,
			id = species.id,
			kg = species.baseKg,
			muts = {},
			growTotal = 100000,
			progress = 0,
		}, lx, lz)
	end
	local function setCash(v: number)
		CurrencyService.set(userId, "cash", v)
	end

	-- Konstanta konfigurasi (PLAN 3.12): 70/45/20 persen dan 30x/80x/250x.
	T.check(
		"Pearl 70% 30x",
		Mutations.list.Pearl.npcSuccess == 0.70 and Mutations.list.Pearl.npcPriceMult == 30
	)
	T.check(
		"Amber 45% 80x",
		Mutations.list.Amber.npcSuccess == 0.45 and Mutations.list.Amber.npcPriceMult == 80
	)
	T.check(
		"Starlit 20% 250x",
		Mutations.list.Starlit.npcSuccess == 0.20 and Mutations.list.Starlit.npcPriceMult == 250
	)

	local eggUid = placeEgg("mutegg1", 12, -10)
	local egg = data.eggs[eggUid]
	T.check("telur placed di Coop", egg ~= nil and egg.loc == "placed")

	-- ===== pilihan (pending) =====
	T.check("tanpa pilihan di awal", MutationService.getPending(userId) == nil)
	T.check("pilih Pearl", MutationService.select(userId, "Pearl") == true)
	T.check("pending = Pearl", MutationService.getPending(userId) == "Pearl")
	T.check("mutasi tak dikenal ditolak", MutationService.select(userId, "Moonlit") == false)
	T.check("pilihan lama tetap setelah penolakan", MutationService.getPending(userId) == "Pearl")
	T.check(
		"cancel membersihkan",
		MutationService.select(userId, "cancel") == true
			and MutationService.getPending(userId) == nil
	)

	-- TTL pilihan (waktu nyata)
	bridge:Invoke("mutation.setTtl", 0.3)
	MutationService.select(userId, "Amber")
	T.check("pilihan aktif sebelum TTL", MutationService.getPending(userId) == "Amber")
	T.wait(0.6)
	T.check("pilihan kedaluwarsa setelah TTL", MutationService.getPending(userId) == nil)
	bridge:Invoke("mutation.setTtl", 30)

	-- ===== harga dan sukses =====
	local baseIncome = PetMath.eggProjectedIncome(egg.id, egg.kg, {})
	local price = Mutations.list.Pearl.npcPriceMult * baseIncome
	T.check("harga = 30 x $/s telur", near(MutationService.price(egg, "Pearl"), price, 1e-9))

	setCash(price - 1)
	MutationService.select(userId, "Pearl")
	local okPoor = MutationService.apply(userId, eggUid, "Pearl", 0)
	T.check("cash kurang ditolak", okPoor == false)
	T.check("cash kurang: saldo utuh", data.cash == price - 1)
	T.check("cash kurang: telur utuh", #egg.muts == 0)
	T.check("cash kurang: pilihan tetap", MutationService.getPending(userId) == "Pearl")

	setCash(price + 500)
	local oldModel = GrowthService.getModel(userId, eggUid)
	local oldIncome = oldModel and oldModel:GetAttribute(Types.Attr.Income)
	local ok, res = MutationService.apply(userId, eggUid, "Pearl", 0)
	T.check("apply sukses (roll 0)", ok == true and res.success == true, res)
	T.check("cash terpotong = harga", near(data.cash, 500, 1e-6), data.cash)
	T.check("muts = Pearl", #egg.muts == 1 and egg.muts[1] == "Pearl")
	T.check("pilihan dibersihkan setelah apply", MutationService.getPending(userId) == nil)
	local newModel = GrowthService.getModel(userId, eggUid)
	local newIncome = newModel and newModel:GetAttribute(Types.Attr.Income)
	T.check("model dibangun ulang", newModel ~= nil and newModel ~= oldModel)
	T.check(
		"atribut Income naik x1.5",
		newIncome and oldIncome and near(newIncome / oldIncome, 1.5, 1e-9),
		newIncome
	)

	-- ===== aturan canAdd =====
	setCash(1e15)
	local dup = MutationService.apply(userId, eggUid, "Pearl", 0)
	T.check("duplikat ditolak", dup == false)
	T.check("duplikat tidak memotong cash", data.cash == 1e15)
	egg.muts = { "Pearl", "Amber", "Moonlit" }
	local full = MutationService.apply(userId, eggUid, "Starlit", 0)
	T.check("maksimal 3 mutasi ditolak", full == false and #egg.muts == 3)
	T.check("Moonlit bukan opsi NPC", MutationService.apply(userId, eggUid, "Moonlit", 0) == false)
	egg.muts = {}

	-- ===== gagal: uang hilang, telur utuh =====
	setCash(1e15)
	local before = data.cash
	local okFail, resFail = MutationService.apply(userId, eggUid, "Starlit", 0.5)
	T.check("apply gagal (roll 0.5 >= 0.2)", okFail == true and resFail.success == false)
	T.check("gagal: uang hilang sebesar harga", near(before - data.cash, resFail.price, 1e-3))
	T.check("gagal: telur utuh tanpa mutasi", data.eggs[eggUid] ~= nil and #egg.muts == 0)
	T.check("harga gagal = 250 x $/s", near(resFail.price, 250 * baseIncome, 1e-6))
	setCash(1e15)
	local okWin, resWin = MutationService.apply(userId, eggUid, "Starlit", 0.1)
	T.check("sukses: biaya sama dengan gagal", okWin and near(resWin.price, resFail.price, 1e-6))
	egg.muts = {}
	T.check(
		"batas roll: npcSuccess - eps sukses",
		select(2, MutationService.apply(userId, eggUid, "Amber", 0.45 - 1e-9)).success == true
	)
	egg.muts = {}
	T.check(
		"batas roll: = npcSuccess gagal",
		select(2, MutationService.apply(userId, eggUid, "Amber", 0.45)).success == false
	)

	-- ===== telur tidak valid =====
	egg.muts = {}
	setCash(1e15)
	data.eggs["mutpocket1"] = {
		id = species.id,
		kg = species.baseKg,
		muts = {},
		growTotal = 100,
		progress = 0,
		loc = "pocket",
		t = 0,
	}
	T.check(
		"telur pocket ditolak",
		MutationService.apply(userId, "mutpocket1", "Pearl", 0) == false
	)
	data.eggs["mutpocket1"] = nil
	GrowthService.setFrozen(userId, eggUid, true)
	T.check(
		"telur beku (dicuri) ditolak",
		MutationService.apply(userId, eggUid, "Pearl", 0) == false
	)
	GrowthService.setFrozen(userId, eggUid, false)
	T.check(
		"uid telur milik pemain lain/tidak ada ditolak",
		MutationService.apply(userId, "uidmilikorang1", "Pearl", 0) == false
	)
	T.check(
		"mutasi tidak dikenal ditolak",
		MutationService.apply(userId, eggUid, "Bogus", 0) == false
	)
	T.check("semua penolakan tidak memotong cash", data.cash == 1e15)

	-- ===== statistik =====
	for _, name in { "Pearl", "Amber", "Starlit" } do
		local p = Mutations.list[name].npcSuccess
		local rolls = RNG.new(7)
		local n, wins, mismatch = 600, 0, 0
		for _ = 1, n do
			egg.muts = {}
			setCash(1e15)
			local roll = rolls:next()
			local _, r = MutationService.apply(userId, eggUid, name, roll)
			if r.success then
				wins += 1
			end
			if r.success ~= (roll < p) then
				mismatch += 1
			end
		end
		T.check(`{name}: sukses sesuai roll (forced)`, mismatch == 0, mismatch)
		T.check(`{name}: frekuensi sukses ~{p}`, math.abs(wins / n - p) < 0.06, wins / n)
	end

	-- RNG internal berseed: deterministik dan mendekati peluang.
	local function runSeeded(seed: number, count: number)
		MutationService.setSeed(seed)
		local out, wins = {}, 0
		for _ = 1, count do
			egg.muts = {}
			setCash(1e15)
			local _, r = MutationService.apply(userId, eggUid, "Pearl", nil)
			table.insert(out, r.success)
			if r.success then
				wins += 1
			end
		end
		return out, wins
	end
	local a, winsA = runSeeded(42, 300)
	local b = runSeeded(42, 300)
	local same = true
	for i = 1, #a do
		if a[i] ~= b[i] then
			same = false
		end
	end
	T.check("seed sama menghasilkan urutan sama", same)
	T.check("RNG berseed ~70% untuk Pearl", math.abs(winsA / 300 - 0.7) < 0.1, winsA / 300)

	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))

	DataService.wipe(userId)
	T.wait(1.2)
end
