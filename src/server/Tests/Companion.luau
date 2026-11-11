--!nonstrict
-- Skenario uji Wave 4: Bud (quest, batas, klaim, buff income/speed, stage 4, quest curian).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Companion")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local PetMath = require(Shared.Logic.PetMath)

local GameEvents = require(Server.Systems.GameEvents)
local DataService = require(Server.Services.DataService)
local IncomeService = require(Server.Services.IncomeService)
local PlacementService = require(Server.Services.PlacementService)
local SpeedService = require(Server.Services.SpeedService)

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
	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		assert(r.ok, r.error)
		return r.result
	end
	local function state()
		return call("companion.state", userId)
	end
	local function grab(zone: number, rarity: number?)
		GameEvents.EggGrabbed:Fire({
			userId = userId,
			eggUid = "t",
			speciesId = "clover_bunny",
			rarity = rarity or 1,
			zone = zone,
			grand = false,
		})
		T.wait(0.05)
	end
	local function hatch(zone: number, rarity: number)
		GameEvents.EggHatched:Fire({
			userId = userId,
			petUid = "t",
			speciesId = "clover_bunny",
			rarity = rarity,
			zone = zone,
			isNew = false,
		})
		T.wait(0.05)
	end
	local function placed(stolen: boolean)
		GameEvents.EggPlaced:Fire({
			userId = userId,
			eggUid = "t",
			speciesId = "clover_bunny",
			stolen = stolen,
		})
		T.wait(0.05)
	end

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true

	local c = state()
	T.check("mulai di stage 1 tanpa progres", c.stage == 1 and next(c.progress) == nil)

	-- ===== Hanya quest stage sekarang yang dihitung =====
	grab(1)
	grab(1)
	grab(3) -- quest stage 2: belum dihitung
	grab(2) -- zona lain: tidak dihitung
	hatch(1, 1)
	c = state()
	T.check("grab zona 1 dihitung", c.progress.s1_grab_meadow == 2, c.progress.s1_grab_meadow)
	T.check("quest stage 2 belum dihitung", c.progress.s2_grab_canopy == nil)
	T.check("hatch dihitung", c.progress.s1_hatch == 1, c.progress.s1_hatch)

	-- ===== Klaim butuh quest lengkap =====
	local r = call("companion.claim", userId)
	T.check("klaim ditolak saat belum lengkap", r.ok == false and state().stage == 1, r.err)
	T.check("tidak ada claimed", next(state().claimed) == nil)

	-- ===== Batas target =====
	for _ = 1, 25 do
		grab(1)
	end
	c = state()
	T.check("grab dibatasi 20", c.progress.s1_grab_meadow == 20, c.progress.s1_grab_meadow)
	r = call("companion.claim", userId)
	T.check("klaim masih ditolak (hatch belum 5)", r.ok == false)

	-- ===== Buff income stage 1: tepat +5% =====
	local species = Creatures.get("clover_bunny")
	data.pets.pettest1 = {
		id = species.id,
		kg = species.baseKg,
		g = "M",
		muts = {},
		eq = true,
		lock = false,
		t = 0,
	}
	local petIncome = PetMath.petIncome(species.id, species.baseKg, {})
	local base = IncomeService.compute(userId, data)
	T.check("income dasar = income pet", base > 0 and near(base, petIncome, 1e-9), base)

	for _ = 1, 5 do
		hatch(4, 1)
	end
	c = state()
	T.check("hatch dibatasi 5", c.progress.s1_hatch == 5, c.progress.s1_hatch)
	r = call("companion.claim", userId)
	T.check("klaim stage 1 berhasil", r.ok == true, r.err)
	c = state()
	T.check("stage naik ke 2", c.stage == 2 and c.claimed["1"] == true)
	local incomeS1 = IncomeService.compute(userId, data)
	T.check("income stage 1 = +5%", near(incomeS1 - base, petIncome * 0.05, 1e-9), incomeS1 - base)
	r = call("companion.claim", userId)
	T.check("klaim ganda ditolak", r.ok == false and state().stage == 2)

	-- ===== Stage 2: speed x1.05 =====
	local speedBefore = SpeedService.getEffectiveSpeed(userId)
	grab(1) -- bukan quest stage 2
	T.check("quest stage 1 tidak bertambah lagi", state().progress.s1_grab_meadow == 20)
	for _ = 1, 15 do
		grab(3)
	end
	hatch(4, 1) -- bukan Frostpeak
	T.check("hatch non-Frostpeak tidak dihitung", state().progress.s2_hatch_frost == nil)
	r = call("companion.claim", userId)
	T.check("stage 2 belum lengkap", r.ok == false)
	hatch(5, 1)
	r = call("companion.claim", userId)
	T.check("klaim stage 2", r.ok == true and state().stage == 3, r.err)
	local speedAfter = SpeedService.getEffectiveSpeed(userId)
	T.check(
		"speed x1.05 setelah stage 2",
		near(speedAfter / speedBefore, 1.05, 1e-9),
		speedAfter / speedBefore
	)
	T.check(
		"income tetap +5% setelah stage 2",
		near(IncomeService.compute(userId, data) - base, petIncome * 0.05, 1e-9)
	)

	-- ===== Stage 3: curian lewat EggPlaced.stolen =====
	placed(false)
	T.check("EggPlaced biasa tidak dihitung", state().progress.s3_steal == nil)
	for _ = 1, 5 do
		placed(true)
	end
	T.check("curian dihitung sampai 5", state().progress.s3_steal == 5, state().progress.s3_steal)
	-- telur curian sungguhan (stolenFrom) lewat PlacementService.insert; tetap dibatasi
	PlacementService.insert(userId, {
		uid = "stolenegg",
		id = species.id,
		kg = species.baseKg,
		muts = {},
		growTotal = 1e9,
		progress = 0,
		stolenFrom = -77,
	}, 12, -10)
	T.wait(0.1)
	T.check("curian tetap dibatasi 5", state().progress.s3_steal == 5)
	hatch(1, 6) -- Mythic: belum Astral
	T.check("Mythic bukan Astral", state().progress.s3_hatch_astral == nil)
	r = call("companion.claim", userId)
	T.check("stage 3 belum lengkap", r.ok == false)
	hatch(1, 7)
	r = call("companion.claim", userId)
	T.check("klaim stage 3", r.ok == true and state().stage == 4, r.err)
	T.check(
		"income stage 3 = +15% total",
		near(IncomeService.compute(userId, data) - base, petIncome * 0.15, 1e-9),
		IncomeService.compute(userId, data) - base
	)

	-- ===== Stage 4: elder =====
	grab(1, 8) -- Void: belum
	T.check("Void bukan Timeless", state().progress.s4_grab_timeless == nil)
	grab(1, 9)
	T.check("Timeless dihitung", state().progress.s4_grab_timeless == 1)
	r = call("companion.claim", userId)
	c = state()
	T.check("klaim stage 4", r.ok == true, r.err)
	T.check(
		"akhir: stage tetap 4, claimed 4, elder",
		c.stage == 4 and c.claimed["4"] == true and c.elder == true
	)
	T.check(
		"income total +20%",
		near(IncomeService.compute(userId, data) - base, petIncome * 0.20, 1e-9),
		IncomeService.compute(userId, data) - base
	)
	r = call("companion.claim", userId)
	T.check("klaim stage 4 ganda ditolak", r.ok == false)
	grab(1, 9)
	T.check("progres tidak berubah setelah selesai", state().progress.s4_grab_timeless == 1)
	T.check(
		"hook progres tidak melewati batas",
		call("companion.progress", userId, "s4_grab_timeless", 5) == nil
	)

	local bad = {}
	for _, line in call("invariants.check") do
		if string.find(line, "[Companion]", 1, true) then
			table.insert(bad, line)
		end
	end
	T.check("invarian Companion bersih", #bad == 0, table.concat(bad, " | "))

	DataService.wipe(userId)
	T.wait(1.2)
	c = state()
	T.check("wipe: kembali ke stage 1", c.stage == 1 and next(c.claimed) == nil and c.elder == nil)
end
