-- Skema profil pemain (docs/PLAN.md §2.6). Field baru boleh ditambah; ProfileStore:Reconcile mengisi default.
-- Naikkan `version` dan tambahkan migrasi di DataService jika bentuk field lama berubah.

return {
	version = 1,

	cash = 0,
	totalEarned = 0,
	peakIncome = 0,
	speedBase = 10,

	wheelLevel = 1,
	penLevel = 1,
	equipSlots = 3,
	plotExpansion = 0,

	trails = { owned = {}, equipped = false },
	pets = {}, -- [uid] = { id, kg, g, muts, eq, lock, t }
	eggs = {}, -- [uid] = { id, kg, muts, growTotal, progress, placed, stolenFrom, t }
	gear = { pan = 1, trap = 0, compass = 0 },
	boosts = { growth2xUntil = 0, lucky2xUntil = 0, speed2xUntil = 0 },
	index = { found = {}, claimed = {}, zoneBonus = {} },

	trophies = 0,
	stardust = 0,
	raceBest = {},
	starwhale = { relayFixed = false, eggsFoundThisVisit = 0, lastVisitId = 0 },
	companion = { stage = 1, progress = {}, claimed = {} },

	lastIncomePerSec = 0,

	freeBasketAt = 0,
	shieldReadyAt = 0,
	newbieProtectUntil = 0,
	lastOnline = 0,

	stats = {
		grabbed = 0,
		stolen = 0,
		beenStolen = 0,
		hatched = 0,
		caught = 0,
		bonks = 0,
		playtime = 0,
	},
	tutorial = { step = 1, done = false },
	settings = { music = true, sfx = true, slowMode = false, lowGfx = false },

	receipts = {}, -- PurchaseId yang sudah diproses (maks 50 terakhir)
	badges = {},
}
