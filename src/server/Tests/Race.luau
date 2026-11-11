--!nonstrict
-- Skenario uji Dash Derby: jadwal (skip), lintasan 8 gerbang, persilangan berurutan (maju/mundur/loncat),
-- terbaik-dari-percobaan, kunci pickup telur di zona race, hadiah saat Closed (peringkat 1/2/3, bonus
-- rekor sekali, tanpa hadiah ganda), pembatalan percobaan saat mati/keluar, invarian.
-- Lambat (~1 menit). Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Race")

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local RaceConfig = require(Shared.Config.RaceConfig)
local RaceMath = require(Shared.Logic.RaceMath)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Bots = require(Server.Systems.Bots)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local TestBridge = require(Server.Systems.TestBridge)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)
local PlotService = require(Server.Services.PlotService)

local BOT_FAST, BOT_SLOW, BOT_START_ONLY, BOT_DEAD = -9101, -9102, -9103, -9104
local STEP = 6 -- stud per langkah (di bawah batas kewajaran sampel 10 Hz)
local STEP_WAIT = 0.15

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage:FindFirstChild(Types.Names.TestBridge)

	local function call(name, ...)
		local result = bridge:Invoke(name, ...)
		return result.ok and result.result or nil
	end
	local function gateZ(zone, index)
		return RaceMath.gateZ(zone, index)
	end
	local function playerMove(x, y, z)
		TestBridge.teleport(userId, Vector3.new(x, y, z))
	end
	local function botMover(id)
		return function(x, y, z)
			Bots.moveTo(id, x, y, z)
		end
	end
	-- Berjalan maju/mundur dari z0 ke z1 dengan langkah kecil (sampler 10 Hz melihat tiap segmen).
	local function walk(move, z0, z1, pause)
		local dir = if z1 >= z0 then 1 else -1
		local z = z0
		local paused = false
		while (z1 - z) * dir > 0 do
			z += dir * math.min(STEP, math.abs(z1 - z))
			move(0, 5, z)
			T.wait(STEP_WAIT)
			if pause and not paused and (z - (z0 + z1) / 2) * dir > 0 then
				paused = true
				T.wait(pause)
			end
		end
	end
	local function jump(move, z)
		move(0, 5, z)
		T.wait(0.35)
	end
	-- Satu putaran penuh melewati semua gerbang (start-9 sampai finish+9).
	local function lap(move, zone, pause)
		jump(move, gateZ(zone, 0) - 9)
		walk(move, gateZ(zone, 0) - 9, gateZ(zone, RaceMath.finishIndex) + 9, pause)
		T.wait(0.3)
	end
	local function attempt(id)
		return call("race.attempt", id)
	end
	local function guardianSleep(zone)
		call("guardian.sleep", zone)
	end
	local function zoneEgg(zone)
		for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
			local uid = model:GetAttribute(Types.Attr.EggUid)
			local entity = uid and EggSpawnService.getEntity(uid)
			if
				entity
				and entity.state == "Occupied"
				and entity.zone == zone
				and not entity.grand
			then
				return entity
			end
		end
		return nil
	end
	local function tryGrab(entity)
		TestBridge.teleport(userId, EggSpawnService.entityPosition(entity) + Vector3.new(4, 4, 0))
		T.wait(0.2)
		local ok, err = CarryService.tryPickupWorld(userId, entity.uid)
		return ok, err
	end
	local function courseGateCount()
		local n = 0
		for _, inst in CollectionService:GetTagged(Types.Tags.RaceGate) do
			if inst:IsDescendantOf(workspace) then
				n += 1
			end
		end
		return n
	end
	local function trophies(id)
		return DataService.getByUserId(id).trophies
	end
	local function prepBot(id)
		Bots.spawn(id)
		DataService.getByUserId(id).tutorial.done = true
		DataService.getByUserId(id).newbieProtectUntil = 0
	end

	call("race.reset")
	DataService.wipe(userId)
	T.wait(1.5)
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true
	data.newbieProtectUntil = 0
	local startTrophies = trophies(userId)

	-- ===== Jadwal lewat skip: Idle -> Countdown -> Open -> Closed -> Idle =====
	T.check("awal Idle", call("race.state").phase == "Idle")
	call("race.skip")
	local s = call("race.state")
	T.check("Countdown 180 dtk", s.phase == "Countdown" and s.remaining == 180, s.remaining)
	T.check("zona 2..12", s.zone and s.zone >= 2 and s.zone <= 12, s.zone)
	T.check("belum ada lintasan saat Countdown", courseGateCount() == 0)
	call("race.skip")
	s = call("race.state")
	T.check("Open 300 dtk", s.phase == "Open" and s.remaining == 300, s.remaining)
	T.check("lintasan ada saat Open", courseGateCount() == 8, courseGateCount())
	call("race.skip")
	T.check("Closed", call("race.state").phase == "Closed")
	T.check("lintasan hilang saat Closed", courseGateCount() == 0)
	T.check("tanpa peserta: tanpa podium", #(call("race.podium").podium or {}) == 0)
	T.check("tanpa peserta: trophy tetap", trophies(userId) == startTrophies)
	call("race.skip")
	s = call("race.state")
	T.check("kembali Idle 1200 dtk", s.phase == "Idle" and s.remaining == 1200, s.remaining)

	-- ===== Race 1: zona 1 =====
	T.check("race.start", call("race.start", 1) == true)
	s = call("race.state")
	T.check("Open zona 1", s.phase == "Open" and s.zone == 1)
	local course = call("race.course")
	T.check("8 gerbang", #course.gates == 8, #course.gates)
	local ordered, tagged = true, true
	for index = 0, 7 do
		local g = course.gates[index + 1]
		if not g or g.index ~= index or math.abs(g.z - gateZ(1, index)) > 0.01 then
			ordered = false
		end
		if not g or g.raceId ~= s.raceId then
			tagged = false
		end
	end
	T.check("gerbang urut dan di posisi", ordered)
	T.check("gerbang beratribut RaceId", tagged)
	T.check("lebar lane", course.halfWidth == 60)
	local effects = workspace:FindFirstChild(Types.Names.Effects)
	T.check(
		"lintasan di Effects",
		effects ~= nil and effects:FindFirstChild(RaceConfig.courseName) ~= nil
	)
	T.check(
		"start di awal+12, finish di akhir-12",
		math.abs(course.gates[1].z - 162) < 0.01 and math.abs(course.gates[8].z - 438) < 0.01
	)

	-- Pickup: terkunci di zona race, boleh di zona lain.
	local egg1 = zoneEgg(1)
	local egg2 = zoneEgg(2)
	T.check("ada telur zona 1 dan 2", egg1 ~= nil and egg2 ~= nil)
	if egg1 and egg2 then
		local ok, err = tryGrab(egg1)
		T.check("pickup zona race ditolak", ok == false and err == RaceConfig.lockedMessage, err)
		T.check("tidak membawa telur", not CarryService.isCarrying(userId))
		local ok2 = tryGrab(egg2)
		T.check("pickup zona lain boleh", ok2 == true)
		CarryService.forceReturn(userId, "returned")
		guardianSleep(2)
		guardianSleep(1)
	end

	-- Persilangan: checkpoint sebelum start diabaikan.
	jump(playerMove, gateZ(1, 1) - 9)
	walk(playerMove, gateZ(1, 1) - 9, gateZ(1, 1) + 9)
	local a = attempt(userId)
	T.check("cp1 tanpa start diabaikan", a.last == nil or a.last == -1, a.last)
	-- Mundur melewati start: tidak memulai.
	jump(playerMove, gateZ(1, 0) + 9)
	walk(playerMove, gateZ(1, 0) + 9, gateZ(1, 0) - 9)
	a = attempt(userId)
	T.check("mundur lewat start diabaikan", a.last == nil or a.last == -1, a.last)
	-- Maju lewat start: mulai, timer berjalan.
	walk(playerMove, gateZ(1, 0) - 9, gateZ(1, 0) + 9)
	a = attempt(userId)
	T.check("start dihitung", a.last == 0, a.last)
	T.check("timer berjalan", a.elapsed ~= nil and a.elapsed > 0.1, a.elapsed)
	-- Loncat ke gerbang 3 (teleport tak wajar), lalu lewati gerbang 3: urutan salah diabaikan.
	jump(playerMove, gateZ(1, 3) - 9)
	walk(playerMove, gateZ(1, 3) - 9, gateZ(1, 3) + 9)
	a = attempt(userId)
	T.check("loncat/urutan salah diabaikan", a.last == 0, a.last)
	-- Mundur ke gerbang 1 (loncat), lalu jalan berurutan ke finish; berhenti sebentar (percobaan lambat).
	jump(playerMove, gateZ(1, 1) - 9)
	walk(playerMove, gateZ(1, 1) - 9, gateZ(1, 7) + 9, 2)
	T.wait(0.3)
	a = attempt(userId)
	T.check("percobaan 1 selesai", a.best ~= nil and a.best > 2, a.best)
	T.check("percobaan direset setelah finish", a.last == -1 and a.elapsed == nil, a.last)
	local slowBest = a.best

	-- Peserta lain berjalan paralel dengan percobaan cepat pemain (bot lambat 1.0 dtk dan 2.5 dtk).
	prepBot(BOT_FAST)
	prepBot(BOT_SLOW)
	prepBot(BOT_START_ONLY)
	prepBot(BOT_DEAD)
	local done = 0
	local function runAsync(fn)
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then
				T.check("lari paralel", false, err)
			end
			done += 1
		end)
	end
	runAsync(function()
		lap(botMover(BOT_FAST), 1, 1.0)
	end)
	runAsync(function()
		lap(botMover(BOT_SLOW), 1, 2.5)
	end)
	runAsync(function()
		-- hanya melewati start lalu berhenti: bukan peserta
		jump(botMover(BOT_START_ONLY), gateZ(1, 0) - 9)
		walk(botMover(BOT_START_ONLY), gateZ(1, 0) - 9, gateZ(1, 0) + 9)
	end)
	runAsync(function()
		-- mulai lalu mati: percobaan batal
		jump(botMover(BOT_DEAD), gateZ(1, 0) - 9)
		walk(botMover(BOT_DEAD), gateZ(1, 0) - 9, gateZ(1, 0) + 9)
	end)
	lap(playerMove, 1, nil)
	local startWait = os.clock()
	while done < 4 and os.clock() - startWait < 30 do
		T.wait(0.2)
	end
	T.check("lari paralel selesai", done == 4, done)

	a = attempt(userId)
	T.check("percobaan lebih cepat menggantikan", a.best ~= nil and a.best < slowBest, a.best)
	local playerBest = a.best
	local fastBest = attempt(BOT_FAST).best
	local slowBotBest = attempt(BOT_SLOW).best
	T.check("bot cepat selesai", fastBest ~= nil)
	T.check("bot lambat selesai", slowBotBest ~= nil)
	T.check(
		"urutan waktu pemain < bot cepat < bot lambat",
		playerBest and fastBest and slowBotBest and playerBest < fastBest and fastBest < slowBotBest,
		`{playerBest} {fastBest} {slowBotBest}`
	)
	T.check("start-saja bukan peserta", attempt(BOT_START_ONLY).best == nil)
	T.check("start-saja mulai percobaan", attempt(BOT_START_ONLY).last == 0)
	-- Mati membatalkan percobaan.
	T.check("bot mati sempat mulai", attempt(BOT_DEAD).last == 0)
	local deadHumanoid = Actors.getHumanoid(BOT_DEAD)
	deadHumanoid.Health = 0
	T.wait(0.4)
	T.check("mati membatalkan percobaan", attempt(BOT_DEAD).last == nil)
	deadHumanoid.Health = deadHumanoid.MaxHealth
	-- Keluar membersihkan.
	Bots.remove(BOT_START_ONLY)
	T.check("keluar membersihkan percobaan", attempt(BOT_START_ONLY).last == nil)

	-- ===== Tutup: hadiah sekali =====
	local before = {
		[userId] = trophies(userId),
		[BOT_FAST] = trophies(BOT_FAST),
		[BOT_SLOW] = trophies(BOT_SLOW),
		[BOT_DEAD] = trophies(BOT_DEAD),
	}
	T.check("raceBest awal kosong", data.raceBest["1"] == nil)
	T.check("race.close", call("race.close") == true)
	s = call("race.state")
	T.check("Closed 15 dtk", s.phase == "Closed" and s.remaining == 15, s.remaining)
	T.check("lintasan dihapus", courseGateCount() == 0 and #call("race.course").gates == 0)
	-- zona 1: dasar 50; juara 1/2/3 x4/x3/x2; +25 rekor (belum ada rekor).
	T.check(
		"juara 1: 50*4+25",
		trophies(userId) - before[userId] == 225,
		trophies(userId) - before[userId]
	)
	T.check(
		"juara 2: 50*3+25",
		trophies(BOT_FAST) - before[BOT_FAST] == 175,
		trophies(BOT_FAST) - before[BOT_FAST]
	)
	T.check(
		"juara 3: 50*2+25",
		trophies(BOT_SLOW) - before[BOT_SLOW] == 125,
		trophies(BOT_SLOW) - before[BOT_SLOW]
	)
	T.check("non-peserta tanpa trophy", trophies(BOT_DEAD) == before[BOT_DEAD])
	data = DataService.getByUserId(userId)
	T.check(
		"raceBest diperbarui",
		data.raceBest["1"] and math.abs(data.raceBest["1"] - playerBest) < 1e-6
	)
	local podium = call("race.podium").podium
	T.check("podium 3 baris", podium and #podium == 3, podium and #podium)
	if podium and #podium == 3 then
		T.check("podium urut", podium[1].userId == userId and podium[2].userId == BOT_FAST)
		T.check("podium juara 3", podium[3].userId == BOT_SLOW)
		T.check(
			"podium waktu dan trophy",
			podium[1].timeSeconds == playerBest and podium[1].trophies == 225
		)
		T.check("podium nama", podium[2].name == Actors.getName(BOT_FAST))
	end
	-- Tutup ulang: tidak ada hadiah kedua.
	T.check("close ulang ditolak", bridge:Invoke("race.close").result == false)
	T.wait(1.2)
	T.check("trophy tidak ganda", trophies(userId) - before[userId] == 225)
	-- Setelah ditutup, pickup zona 1 boleh lagi.
	if egg1 and EggSpawnService.getEntity(egg1.uid) then
		local ok = tryGrab(egg1)
		T.check("pickup zona 1 boleh setelah race", ok == true)
		CarryService.forceReturn(userId, "returned")
		guardianSleep(1)
	end

	-- ===== Race 2: zona 2, rekor lama lebih cepat -> tanpa bonus rekor =====
	Bots.removeAll()
	call("race.reset")
	data = DataService.getByUserId(userId)
	data.raceBest["2"] = 0.5
	local trophies2 = trophies(userId)
	T.check("race 2 start", call("race.start", 2) == true)
	lap(playerMove, 2, nil)
	T.check("race 2 percobaan selesai", attempt(userId).best ~= nil)
	call("race.close")
	T.check(
		"zona 2 juara 1 tanpa rekor: 100*4",
		trophies(userId) - trophies2 == 400,
		trophies(userId) - trophies2
	)
	T.check("rekor lama tidak diganti", data.raceBest["2"] == 0.5)

	-- ===== Pemulihan =====
	call("race.reset")
	Bots.removeAll()
	data = DataService.getByUserId(userId)
	data.raceBest = {}
	require(Server.Services.CurrencyService).set(userId, "trophies", 0)
	PlotService.teleportToPlot(userId)
	T.wait(1.2)
	s = call("race.state")
	T.check("state dipulihkan", s.phase == "Idle" and courseGateCount() == 0)
	local violations = InvariantChecker.check()
	T.check("invarian bersih", #violations == 0, table.concat(violations, "; "))
end
