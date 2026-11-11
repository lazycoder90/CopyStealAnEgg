--!nonstrict
-- Skenario uji monetisasi + badge. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Monetization")
-- Semua id Robux uji palsu (didaftarkan lewat hook, bukan config) dan dihapus di akhir; override
-- kepemilikan dihapus; profil di-wipe di akhir agar pemeriksa invarian tetap bersih.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Progression = require(Shared.Config.Progression)
local Types = require(Shared.Types)

local Clock = require(Server.Systems.Clock)
local GameEvents = require(Server.Systems.GameEvents)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)

local PRODUCT_BASE = 777000

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge
	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		if not r.ok then
			T.check("hook " .. name, false, r.error)
		end
		return r.result
	end
	local function data()
		return DataService.getByUserId(userId)
	end
	local function near(a, b, tol)
		return math.abs(a - b) <= tol
	end

	local registered = {}
	local nextProduct = PRODUCT_BASE
	local function product(kind, arg)
		nextProduct += 1
		call("monetization.registerProduct", nextProduct, kind, arg)
		table.insert(registered, nextProduct)
		return nextProduct
	end
	local nextPurchase = 900000
	local function receipt(productId, purchaseId)
		if not purchaseId then
			nextPurchase += 1
			purchaseId = nextPurchase
		end
		return { PlayerId = userId, PurchaseId = purchaseId, ProductId = productId }
	end
	local function process(productId, purchaseId)
		return call("monetization.process", receipt(productId, purchaseId))
	end
	local function receiptCount()
		local n = 0
		for _ in data().receipts do
			n += 1
		end
		return n
	end

	local speciesId = Creatures.list[1].id
	local eggCount = 0
	local function addEgg(uid, growTotal, progress)
		eggCount += 1
		data().eggs[uid] = {
			id = speciesId,
			kg = 1,
			muts = {},
			growTotal = growTotal,
			progress = progress or 0,
			loc = "placed",
			pos = { x = -24 + eggCount * 4, z = 0 },
			t = 0,
		}
		GrowthService.ensureModel(userId, uid)
	end
	local function clearEggs()
		for uid in data().eggs do
			GrowthService.removeModel(userId, uid)
			data().eggs[uid] = nil
		end
	end

	local function fresh()
		DataService.wipe(userId)
		T.wait(1.2)
		eggCount = 0
	end

	fresh()
	local petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	T.wait(1.5)

	-- ===== Config id 0: tidak ada produk, tidak ada Prompt =====
	T.check("config: tidak ada produk terdaftar", call("monetization.productCount") == 0)
	T.check(
		"id 0 ditolak registerProduct",
		call("monetization.registerProduct", 0, "cash", 30) == false
	)
	T.check("id 0 tidak terdaftar", call("monetization.hasProduct", 0) == false)
	addEgg("mt_a", 1000, 0)
	local before = call("monetization.promptCount")
	T.check(
		"skip id 0 -> unavailable",
		call("monetization.requestSkip", userId, "mt_a") == "unavailable"
	)
	T.check(
		"growAll id 0 -> unavailable",
		call("monetization.requestGrowAll", userId) == "unavailable"
	)
	T.check(
		"skip telur tidak ada -> invalid",
		call("monetization.requestSkip", userId, "mt_none") == "invalid"
	)
	T.check("tanpa panggilan Prompt", call("monetization.promptCount") == before)
	T.check("pendingSkip kosong", next(data().pendingSkip) == nil)
	clearEggs()

	-- ===== ProcessReceipt: produk/pemain tidak dikenal =====
	T.check("produk tidak dikenal -> NotProcessedYet", process(123456789) == false)
	local ghost = bridge:Invoke("monetization.process", {
		PlayerId = -424242,
		PurchaseId = 1,
		ProductId = PRODUCT_BASE,
	})
	T.check("pemain tanpa profil -> NotProcessedYet", ghost.ok and ghost.result == false)

	-- ===== Idempotensi + paket cash =====
	local income = call("income.compute", userId)
	T.check("income $3/s", near(income, 3, 1e-6), income)
	local cashSmall = product("cash", 30)
	local cashMedium = product("cash", 120)
	local cashLarge = product("cash", 480)
	local c0 = data().cash
	local r1 = receipt(cashSmall)
	T.check("receipt pertama granted", call("monetization.process", r1) == true)
	local c1 = data().cash
	T.check("cash pack 30 menit", near(c1 - c0, income * 1800, 40), c1 - c0)
	T.check("receipt kedua (sama) granted", call("monetization.process", r1) == true)
	local c2 = data().cash
	T.check("tidak memberi dua kali", c2 - c1 < 40, c2 - c1)
	T.check("receipt tercatat", data().receipts[tostring(r1.PurchaseId)] ~= nil)
	local m0 = data().cash
	process(cashMedium)
	T.check("cash pack 2 jam", near(data().cash - m0, income * 7200, 60), data().cash - m0)
	local l0 = data().cash
	process(cashLarge)
	T.check("cash pack 8 jam", near(data().cash - l0, income * 28800, 100), data().cash - l0)

	-- ===== Pemangkasan receipts =====
	for i = 1, 130 do
		data().receipts[tostring(i)] = Clock.now() - 5000 - i
	end
	local pruneProduct = product("cash", 1)
	local pruneId = 990001
	T.check("process saat penuh berhasil", process(pruneProduct, pruneId) == true)
	T.check("receipts dipangkas ke 100", receiptCount() == 100, receiptCount())
	T.check("receipt terbaru dipertahankan", data().receipts[tostring(pruneId)] ~= nil)
	T.check("receipt terlama dibuang", data().receipts["130"] == nil)
	for _, v in call("invariants.check") do
		T.check("invarian Monetization bersih", not string.find(v, "%[Monetization%]"), v)
	end
	data().receipts = {}

	-- ===== Efek gamepass =====
	local function effects()
		return call("monetization.passEffects", userId)
	end
	local base = effects()
	local function passRatio(key, field, expected)
		call("monetization.setOwned", userId, key, true)
		local owned = effects()
		T.check(
			key .. " x" .. expected,
			near(owned[field] / base[field], expected, 1e-6),
			owned[field]
		)
		call("monetization.setOwned", userId, key, nil)
		local cleared = effects()
		T.check(
			key .. " inert setelah dibersihkan",
			near(cleared[field] / base[field], 1, 1e-6),
			cleared[field]
		)
	end
	passRatio("money2x", "income", 2)
	passRatio("speed2x", "speed", 2)
	passRatio("fastGrowth", "growth", 1.5)
	passRatio("lucky", "luck", 2)
	local capBase = call("offline.simulate", userId, 1).cap
	call("monetization.setOwned", userId, "vip", true)
	local capVip = call("offline.simulate", userId, 1).cap
	call("monetization.setOwned", userId, "vip", nil)
	T.check("vip: cap offline x2", near(capVip / capBase, 2, 1e-6), capVip)
	T.check("vip dibersihkan", call("offline.simulate", userId, 1).cap == capBase)

	-- ===== equip3 sekali =====
	fresh()
	T.check("slot awal 3", data().equipSlots == 3)
	call("monetization.setOwned", userId, "equip3", true)
	T.check("equip3 -> 6 slot", data().equipSlots == 6, data().equipSlots)
	T.check("penanda passes.equip3", data().passes.equip3 == true)
	call("monetization.setOwned", userId, "equip3", true)
	T.check("tidak diberikan dua kali", data().equipSlots == 6, data().equipSlots)
	call("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	T.check("rejoin menjaga 6 slot", data().equipSlots == 6, data().equipSlots)
	call("monetization.setOwned", userId, "equip3", true)
	T.check("rejoin tidak menggandakan", data().equipSlots == 6, data().equipSlots)
	call("monetization.setOwned", userId, "equip3", nil)
	T.check("penanda bertahan", data().passes.equip3 == true)

	-- ===== Skip Growth =====
	fresh()
	petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	T.wait(1.5)
	local skip = product("skipGrowth", 5) -- tier tertinggi: boleh menyelesaikan semua telur uji
	addEgg("sk_a", 1000, 0)
	addEgg("sk_b", 5000, 0)
	addEgg("sk_c", 200, 0)
	data().pendingSkip = { uid = "sk_a", at = Clock.now() }
	T.check("skip: granted", process(skip) == true)
	T.check("skip: telur target selesai", data().eggs.sk_a.progress == data().eggs.sk_a.growTotal)
	T.check(
		"skip: telur lain tidak",
		data().eggs.sk_b.progress < 100 and data().eggs.sk_c.progress < 100
	)
	T.check("skip: pendingSkip dibersihkan", next(data().pendingSkip) == nil)
	T.check(
		"skip: model ready",
		GrowthService.getModel(userId, "sk_a"):GetAttribute(Types.Attr.Ready) == true
	)

	data().pendingSkip = { uid = "sk_c", at = Clock.now() }
	call("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	T.check("pendingSkip bertahan setelah rejoin", data().pendingSkip.uid == "sk_c")
	process(skip)
	T.check(
		"skip setelah rejoin: sk_c selesai",
		data().eggs.sk_c.progress == data().eggs.sk_c.growTotal
	)

	data().pendingSkip = { uid = "hilang", at = Clock.now() }
	process(skip)
	T.check(
		"skip fallback: telur terlama selesai",
		data().eggs.sk_b.progress == data().eggs.sk_b.growTotal
	)

	-- Produk Skip murah (tier 1) tidak boleh menyelesaikan telur yang butuh tier lebih tinggi.
	local skipLow = product("skipGrowth", 1)
	addEgg("sk_d", 5000, 0)
	data().pendingSkip = { uid = "sk_d", at = Clock.now() }
	local cashBefore = data().cash
	T.check("skip murah: granted", process(skipLow) == true)
	T.check("skip murah tidak menyelesaikan telur mahal", data().eggs.sk_d.progress < 100)
	T.check("skip murah: dikompensasi uang", data().cash > cashBefore)
	T.check("skip murah: pendingSkip dibersihkan", next(data().pendingSkip) == nil)
	-- Bersihkan telur uji agar skenario "tanpa target" berikutnya benar-benar tanpa target.
	GrowthService.removeModel(userId, "sk_d")
	data().eggs.sk_d = nil

	local cc0 = data().cash
	data().pendingSkip = { uid = "hilang", at = Clock.now() }
	process(skip)
	T.check(
		"skip tanpa target: kompensasi cash 5 menit",
		near(data().cash - cc0, 3 * 300, 40),
		data().cash - cc0
	)
	T.check("pendingSkip bersih", next(data().pendingSkip) == nil)

	-- ===== Grow All =====
	clearEggs()
	local growAll = product("growAll", 0)
	addEgg("ga_a", 1000, 0)
	addEgg("ga_b", 2000, 0)
	addEgg("ga_c", 3000, 3000)
	process(growAll)
	T.check(
		"growAll: semua selesai",
		data().eggs.ga_a.progress == 1000 and data().eggs.ga_b.progress == 2000
	)
	clearEggs()

	-- ===== Wheel +1 =====
	local wheel = product("wheel", 1)
	data().wheelLevel = 3
	process(wheel)
	T.check("wheel +1", data().wheelLevel == 4, data().wheelLevel)
	data().wheelLevel = Progression.wheel.maxLevel
	T.check("wheel di maksimum tetap granted", process(wheel) == true)
	T.check("wheel tidak melewati maksimum", data().wheelLevel == Progression.wheel.maxLevel)
	data().wheelLevel = 1

	-- ===== Potion =====
	local now = Clock.now()
	process(product("potion", "speed"))
	T.check(
		"potion speed 5 menit",
		near(data().boosts.speed2xUntil, now + 300, 3),
		data().boosts.speed2xUntil
	)
	process(product("potion", "luck"))
	T.check("potion luck 10 menit", near(data().boosts.lucky2xUntil, now + 600, 3))
	process(product("potion", "growth"))
	T.check("potion growth 10 menit", near(data().boosts.growth2xUntil, now + 600, 3))
	data().boosts.lucky2xUntil = now + 5000
	process(product("potion", "luck"))
	T.check("potion tidak memperpendek boost", data().boosts.lucky2xUntil == now + 5000)
	data().boosts = { growth2xUntil = 0, lucky2xUntil = 0, speed2xUntil = 0 }

	-- ===== Trail =====
	local trailId = Progression.trails[1].id
	local trail = product("trail", trailId)
	process(trail)
	T.check("trail dimiliki", data().trails.owned[trailId] == true)
	process(trail)
	T.check("trail tetap satu", data().trails.owned[trailId] == true)
	local badTrail = product("trail", "tidak_ada")
	local badReceipt = receipt(badTrail)
	T.check(
		"trail tak dikenal -> NotProcessedYet",
		call("monetization.process", badReceipt) == false
	)
	T.check("grant gagal tidak dicatat", data().receipts[tostring(badReceipt.PurchaseId)] == nil)

	-- ===== Shield (varian reset cooldown) =====
	local shield = product("shield", 10)
	T.check("shield granted", process(shield) == true)
	T.check("shield aktif", call("defense.stats").shields >= 1)
	T.check("shield kedua (aktif) tetap granted", process(shield) == true)

	-- ===== PurchaseGranted event =====
	local events = {}
	local connection = GameEvents.PurchaseGranted:Connect(function(e)
		table.insert(events, e)
	end)
	process(product("cash", 1))
	T.wait(0.1)
	connection.Disconnect()
	T.check(
		"event PurchaseGranted",
		#events == 1 and events[1].userId == userId and events[1].kind == "cash"
	)

	-- ===== Badge =====
	fresh()
	T.check("badge awal kosong", #call("badge.list", userId) == 0)
	data().eggs.bd_a = {
		id = speciesId,
		kg = 1,
		muts = {},
		growTotal = 10,
		progress = 10,
		loc = "placed",
		pos = { x = 0, z = 10 },
		t = 0,
	}
	GrowthService.ensureModel(userId, "bd_a")
	local hatched = call("hatch.hatch", userId, "bd_a")
	T.check("hatch berhasil", hatched.ok == true)
	T.wait(0.2)
	T.check("FirstHatch lewat event", data().badges.FirstHatch == true)
	T.check("award kedua false", call("badge.award", userId, "FirstHatch") == false)
	T.check("award badge tak dikenal false", call("badge.award", userId, "NopeBadge") == false)

	GameEvents.EggPlaced:Fire({
		userId = userId,
		eggUid = "x",
		speciesId = speciesId,
		stolen = false,
	})
	T.wait(0.1)
	T.check("tidak ada FirstSteal tanpa curian", data().badges.FirstSteal == nil)
	GameEvents.EggPlaced:Fire({
		userId = userId,
		eggUid = "x",
		speciesId = speciesId,
		stolen = true,
	})
	T.wait(0.1)
	T.check("FirstSteal", data().badges.FirstSteal == true)

	GameEvents.ZoneChanged:Fire({ userId = userId, zone = 9 })
	T.wait(0.1)
	T.check("Zone5 dan Zone9", data().badges.Zone5 == true and data().badges.Zone9 == true)
	T.check("Zone12 belum", data().badges.Zone12 == nil)
	GameEvents.ZoneChanged:Fire({ userId = userId })
	T.wait(0.1)

	T.check("award manual pertama true", call("badge.award", userId, "Zone12") == true)
	local trophyOk = bridge:Invoke("badge.award", userId, "RaceWinner")
	T.check("RaceWinner manual", trophyOk.ok and trophyOk.result == true)
	local list = call("badge.list", userId)
	T.check("daftar badge", #list == 6, #list)

	-- ===== Pemulihan =====
	for _, id in registered do
		call("monetization.unregisterProduct", id)
	end
	T.check("produk uji dihapus", call("monetization.productCount") == 0)
	local final = effects()
	T.check("provider inert di akhir", final.luck == 1)
	fresh()
	for _, v in call("invariants.check") do
		T.check("invarian Monetization bersih (akhir)", not string.find(v, "%[Monetization%]"), v)
	end
end
