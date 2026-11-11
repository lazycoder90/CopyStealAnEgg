--!nonstrict
-- Skenario uji penghasilan offline. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Offline")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Formulas = require(Shared.Logic.Formulas)

local Clock = require(Server.Systems.Clock)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)

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

	DataService.wipe(userId)
	T.wait(1.2)
	local data = DataService.getByUserId(userId)

	-- income dikenal: Pebble Chick 1.2 kg = $3/s
	local petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	T.wait(1.5) -- tick income menyimpan lastIncomePerSec
	data = DataService.getByUserId(userId)
	local income = call("income.compute", userId)
	T.check("income $3/s", math.abs(income - 3) < 1e-6, income)
	T.check("lastIncomePerSec tersimpan", math.abs(data.lastIncomePerSec - 3) < 1e-6)

	-- telur uji: placed biasa, placed beku, pocket
	local speciesId = Creatures.list[1].id
	local function addEgg(uid, loc)
		data.eggs[uid] = {
			id = speciesId,
			kg = 1,
			muts = {},
			growTotal = 100000,
			progress = 0,
			loc = loc,
			pos = if loc == "placed" then { x = 0, z = 0 } else nil,
			t = 0,
		}
	end
	addEgg("offtest_a", "placed")
	addEgg("offtest_b", "placed")
	addEgg("offtest_c", "pocket")
	GrowthService.setFrozen(userId, "offtest_b", true)

	-- 2 jam offline
	local cash0 = data.cash
	local r = call("offline.simulate", userId, 7200)
	local expected = Formulas.offlineEarned(3, 7200, 86400)
	T.check("earned sesuai Formulas.offlineEarned", math.abs(r.earned - expected) < 1e-6, r.earned)
	T.check("elapsed 7200", r.elapsed == 7200, r.elapsed)
	local gained = DataService.getByUserId(userId).cash - cash0
	T.check("cash bertambah sebesar earned", gained >= expected and gained <= expected + 30, gained)
	data = DataService.getByUserId(userId)
	T.check(
		"telur placed maju sebesar elapsed",
		data.eggs.offtest_a.progress >= 7200 and data.eggs.offtest_a.progress < 7200 + 400,
		data.eggs.offtest_a.progress
	)
	T.check(
		"telur beku tidak maju",
		data.eggs.offtest_b.progress == 0,
		data.eggs.offtest_b.progress
	)
	T.check("telur pocket tidak maju", data.eggs.offtest_c.progress == 0)
	T.check("lastOnline direset", math.abs(data.lastOnline - Clock.now()) <= 3)
	local banner = call("offline.lastBanner", userId)
	T.check("banner terkirim", banner ~= nil)
	T.check("banner amount", banner and math.abs(banner.amount - expected) < 1e-6)
	T.check(
		"banner perDay = offlinePerDay",
		banner and math.abs(banner.perDay - Formulas.offlinePerDay(3)) < 1e-6
	)

	-- < 60 detik: tanpa banner
	call("offline.simulate", userId, 30)
	T.check("tanpa banner untuk < 60 detik", call("offline.lastBanner", userId) == nil)

	-- cap 24 jam
	local capped = call("offline.simulate", userId, 48 * 3600)
	T.check("cap 24 jam", capped.cap == 86400 and capped.elapsed == 86400, capped.elapsed)
	T.check(
		"earned di cap",
		math.abs(capped.earned - Formulas.offlineEarned(3, 86400, 86400)) < 1e-6
	)

	-- cap 36 jam di pen level 8
	data = DataService.getByUserId(userId)
	data.penLevel = 8
	local capped8 = call("offline.simulate", userId, 48 * 3600)
	T.check("cap 36 jam di pen 8", capped8.cap == 129600 and capped8.elapsed == 129600, capped8.cap)
	data.penLevel = 1

	-- lastOnline == 0: tanpa bayaran, tetap direset
	data.lastOnline = 0
	local cashBefore = data.cash
	local fresh = call("offline.simulate", userId, nil)
	T.check("tanpa bayaran saat lastOnline 0", fresh.earned == 0 and fresh.elapsed == 0)
	data = DataService.getByUserId(userId)
	T.check("cash tidak lonjak", data.cash - cashBefore < 30, data.cash - cashBefore)
	T.check("lastOnline diisi untuk profil baru", data.lastOnline > 0)
	T.check("tanpa banner", call("offline.lastBanner", userId) == nil)

	-- tidak ada hitung ganda setelah simulateRejoin
	data.eggs = {}
	local cashRejoin = data.cash
	call("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	T.check("rejoin: tanpa hitung ganda", data.cash - cashRejoin < 30, data.cash - cashRejoin)
	T.check("rejoin: tanpa banner", call("offline.lastBanner", userId) == nil)

	-- invarian
	local violations = call("invariants.check")
	local bad = {}
	for _, v in violations do
		if string.find(v, "Offline", 1, true) or string.find(v, "lastOnline", 1, true) then
			table.insert(bad, v)
		end
	end
	T.check("invarian Offline ok", #bad == 0, table.concat(bad, "; "))

	DataService.wipe(userId)
	T.wait(1.2)
end
