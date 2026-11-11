--!nonstrict
-- Skenario uji Wave 4: siklus siang/malam, pengali tumbuh malam, Moonlit, payload remote, force.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "DayNight")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local EventsConfig = require(Shared.Config.EventsConfig)
local Mutations = require(Shared.Config.Mutations)

local Clock = require(Server.Systems.Clock)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local PlacementService = require(Server.Services.PlacementService)

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

	local origState = call("daynight.state")
	local origScale = Clock.timeScale
	local origChance = Mutations.moonlitChancePerNight
	local BOT = -41

	local function cleanup()
		Clock.timeScale = origScale
		Mutations.moonlitChancePerNight = origChance
		call("bot.removeAll")
		call("daynight.restore", origState.state, origState.remaining)
	end

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true

	-- ===== Fase dan durasi =====
	T.check("durasi siang 240", EventsConfig.dayNight.daySeconds == 240)
	T.check("durasi malam 90", EventsConfig.dayNight.nightSeconds == 90)
	call("daynight.seed", 123)
	call("daynight.force", "Day", true)
	local s = call("daynight.state")
	T.check("force Day: timer penuh", s.state == "Day" and s.remaining == 240, s.remaining)
	call("daynight.tick", 239.5)
	s = call("daynight.state")
	T.check("masih siang", s.state == "Day" and math.abs(s.remaining - 0.5) < 1e-6, s.remaining)
	call("daynight.tick", 1)
	s = call("daynight.state")
	T.check("berganti ke malam", s.state == "Night", s.state)
	T.check("sisa malam membawa sisa dt", math.abs(s.remaining - 89.5) < 1e-6, s.remaining)
	local payload = call("daynight.lastPayload")
	T.check(
		"payload remote berisi fase baru",
		payload and payload.state == "Night" and payload.remaining == 89.5,
		payload and payload.remaining
	)
	call("daynight.tick", 100)
	s = call("daynight.state")
	T.check("kembali ke siang", s.state == "Day", s.state)
	T.check("sisa siang 229.5", math.abs(s.remaining - 229.5) < 1e-6, s.remaining)

	call("daynight.force", "Night", true)
	s = call("daynight.state")
	T.check("force Night: timer 90", s.state == "Night" and s.remaining == 90, s.remaining)
	payload = call("daynight.lastPayload")
	T.check(
		"payload force = Night 90",
		payload and payload.state == "Night" and payload.remaining == 90
	)

	-- ===== Pengali tumbuh =====
	call("daynight.force", "Day", true)
	T.check(
		"siang: pengali 1",
		GrowthService.multiplier(userId) == 1,
		GrowthService.multiplier(userId)
	)
	call("daynight.force", "Night", true)
	T.check(
		"malam: pengali 30",
		GrowthService.multiplier(userId) == 30,
		GrowthService.multiplier(userId)
	)
	call("daynight.force", "Day", true)
	T.check("siang lagi: pengali 1", GrowthService.multiplier(userId) == 1)

	-- ===== Laju tumbuh telur placed: ~30x pada malam =====
	local species = Creatures.get("clover_bunny")
	local uid = PlacementService.insert(userId, {
		uid = "dnegg1",
		id = species.id,
		kg = species.baseKg,
		muts = {},
		growTotal = 1e9,
		progress = 0,
	}, 12, -10)
	local function sample(prev)
		local deadline = os.clock() + 2.5
		while os.clock() < deadline do
			local p = data.eggs[uid].progress
			if p ~= prev then
				return p, os.clock()
			end
			T.wait(0.05)
		end
		return data.eggs[uid].progress, os.clock()
	end
	local function rate()
		local p0, t0 = sample(-1)
		T.wait(3)
		local p1, t1 = sample(p0)
		return (p1 - p0) / (t1 - t0)
	end
	call("daynight.force", "Day", true)
	local dayRate = rate()
	call("daynight.force", "Night", true)
	local nightRate = rate()
	call("daynight.force", "Day", true)
	T.check("laju siang ~1x", dayRate > 0.8 and dayRate < 1.3, dayRate)
	T.check("laju malam ~30x", nightRate > 24 and nightRate < 37, nightRate)
	T.check(
		"malam ~30x siang",
		nightRate / dayRate > 20 and nightRate / dayRate < 40,
		nightRate / dayRate
	)

	-- ===== Clock.timeScale mempercepat timer fase =====
	call("daynight.restore", "Day", 200)
	Clock.timeScale = 10
	T.wait(2.5)
	Clock.timeScale = origScale
	s = call("daynight.state")
	T.check("timeScale 10 memajukan timer", s.remaining < 185 and s.remaining > 150, s.remaining)

	-- ===== Moonlit =====
	local statsOk = pcall(call, "bot.spawn", BOT)
	T.check("bot spawn", statsOk)
	local ids = {}
	for _ = 1, 3 do
		local r = call("bot.giveEgg", BOT, species.id, nil, false)
		if r.uid then
			table.insert(ids, r.uid)
		end
	end
	local botData = DataService.getByUserId(BOT)
	T.check("bot punya 3 telur placed", #ids == 3, #ids)

	local function resetMuts()
		for _, id in ids do
			botData.eggs[id].muts = {}
		end
	end
	local function simulate(seed, rounds)
		call("daynight.seed", seed)
		local hits = 0
		for _ = 1, rounds do
			hits += call("daynight.moonlit", BOT)
			resetMuts()
		end
		return hits
	end
	local rounds = 1500
	local hitsA = simulate(77, rounds)
	local hitsB = simulate(77, rounds)
	local trials = rounds * #ids
	local expected = trials * origChance
	T.check("seed sama: hasil sama", hitsA == hitsB, `{hitsA} vs {hitsB}`)
	T.check(
		"frekuensi Moonlit ~4%",
		math.abs(hitsA - expected) < 5 * math.sqrt(expected),
		`{hitsA} dari {trials}, harapan {expected}`
	)

	-- Aturan: pakai peluang 100% supaya deterministik.
	Mutations.moonlitChancePerNight = 1
	resetMuts()
	local first = botData.eggs[ids[1]]
	local second = botData.eggs[ids[2]]
	T.check("semua telur layak dapat Moonlit", call("daynight.moonlit", BOT) == #ids)
	T.check("telur bermutasi Moonlit", first.muts[1] == "Moonlit" and #first.muts == 1)
	T.check("Moonlit tidak ganda", call("daynight.moonlit", BOT) == 0 and #first.muts == 1)

	first.muts = { "Pearl", "Amber", "Starlit" }
	second.muts = {}
	botData.eggs[ids[3]].muts = {}
	GrowthService.setFrozen(BOT, ids[2], true)
	local n = call("daynight.moonlit", BOT)
	GrowthService.setFrozen(BOT, ids[2], false)
	T.check("telur 3 mutasi tidak ditambah", #first.muts == 3 and first.muts[3] == "Starlit")
	T.check("telur beku dilewati", #second.muts == 0, #second.muts)
	T.check("hanya telur layak yang kena", n == 1 and botData.eggs[ids[3]].muts[1] == "Moonlit", n)

	local pocketEgg = botData.eggs[ids[3]]
	pocketEgg.muts = {}
	pocketEgg.loc = "pocket"
	pocketEgg.pos = nil
	second.muts = { "Moonlit" }
	T.check("telur pocket dilewati", call("daynight.moonlit", BOT) == 0 and #pocketEgg.muts == 0)
	Mutations.moonlitChancePerNight = origChance

	-- Malam benar-benar memanggil roll untuk pemain online (peluang 100% pada telur pemain)
	Mutations.moonlitChancePerNight = 1
	call("daynight.restore", "Day", 1)
	call("daynight.tick", 2)
	Mutations.moonlitChancePerNight = origChance
	T.check(
		"awal malam menandai telur pemain Moonlit",
		table.find(data.eggs[uid].muts, "Moonlit") ~= nil,
		table.concat(data.eggs[uid].muts, ",")
	)

	cleanup()
	DataService.wipe(userId)
	T.wait(1.2)
	T.check("fase dipulihkan", call("daynight.state").state == origState.state)
	T.check(
		"pengali kembali normal",
		(origState.state == "Day") == (GrowthService.multiplier(userId) < 30)
	)
end
