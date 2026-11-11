--!nonstrict
-- Skenario uji Wave 4: rantai Starwhale (puzzle Star Relay, kompas, penampakan, telur aneh, pod, trade).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Starwhale")

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Layout = require(Shared.Config.Layout)
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)
local PipePuzzle = require(Shared.Logic.PipePuzzle)
local StarwhaleMath = require(Shared.Logic.StarwhaleMath)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Clock = require(Server.Systems.Clock)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local TestBridge = require(Server.Systems.TestBridge)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local PlacementService = require(Server.Services.PlacementService)
local StarwhaleService = require(Server.Services.StarwhaleService)

local CFG = StarwhaleConfig

local function dist3(a: Vector3, b: { number }): number
	return math.sqrt((a.X - b[1]) ^ 2 + (a.Y - b[2]) ^ 2 + (a.Z - b[3]) ^ 2)
end

local function planar(a: Vector3, b: { number }): number
	return math.sqrt((a.X - b[1]) ^ 2 + (a.Z - b[3]) ^ 2)
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge
	local function call(name, ...)
		local res = bridge:Invoke(name, ...)
		return res.ok, res.result
	end
	local function tp(pos: Vector3)
		TestBridge.teleport(userId, pos)
		T.wait(0.15)
	end
	local function count(tag: string): number
		return #CollectionService:GetTagged(tag)
	end

	StarwhaleService.endVisit()
	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	local startStardust = data.stardust

	-- ===== Star Relay =====
	T.check("relay belum diperbaiki", data.starwhale.relayFixed == false and data.gear.compass == 0)
	T.check("tanpa puzzle submit ditolak", StarwhaleService.submit(userId, {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
	}) == false)
	T.check("relay tetap rusak", data.starwhale.relayFixed == false)

	T.check("requestPuzzle ok", StarwhaleService.requestPuzzle(userId) == true)
	local _, payload = call("starwhale.lastPayload", userId)
	T.check("payload puzzle terkirim", payload ~= nil and payload.puzzle ~= nil)
	local puzzle = payload and payload.puzzle
	T.check(
		"puzzle 5x5 tanpa solusi",
		puzzle ~= nil and puzzle.size == 5 and puzzle.solution == nil
	)
	T.check("fase Idle tanpa kunjungan", payload ~= nil and payload.phase == "Idle")
	T.check(
		"source/target valid",
		puzzle ~= nil
			and puzzle.source.col == 1
			and puzzle.target.col == 5
			and #puzzle.tiles == 5
			and #puzzle.tiles[1] == 5
	)
	local _, solution = call("starwhale.puzzle", userId)
	T.check("solusi hanya lewat hook uji", solution ~= nil and #solution == 5)

	-- Submit salah: rotasi awal (belum selesai), tipe salah, ukuran salah, di luar rentang.
	local current = {}
	for r = 1, 5 do
		current[r] = {}
		for c = 1, 5 do
			current[r][c] = puzzle.tiles[r][c].rot
		end
	end
	T.check("rotasi awal belum selesai", StarwhaleService.submit(userId, current) == false)
	T.check("submit string ditolak", StarwhaleService.submit(userId, "solved") == false)
	T.check("submit nil ditolak", StarwhaleService.submit(userId, nil) == false)
	T.check("submit grid kecil ditolak", StarwhaleService.submit(userId, { { 0 } }) == false)
	local bad = {}
	for r = 1, 5 do
		bad[r] = { 0, 0, 0, 0, 0 }
	end
	bad[2][3] = 9
	T.check("rotasi di luar 0..3 ditolak", StarwhaleService.submit(userId, bad) == false)
	T.check(
		"relay tetap rusak setelah gagal",
		data.starwhale.relayFixed == false and data.gear.compass == 0
	)
	local validator = Check.args(Check.intGrid(5, 5, 0, 3))
	T.check(
		"validator menolak grid rusak",
		validator(bad) == false and validator({ 1, 2 }) == false
	)
	T.check("validator menerima grid benar", validator(solution) == true)
	local _, info = call("starwhale.info", userId)
	T.check("puzzle yang sama tetap menunggu", info.hasPending == true)

	-- Puzzle dibuat per permintaan.
	T.wait(0.35)
	StarwhaleService.requestPuzzle(userId)
	local _, solution2 = call("starwhale.puzzle", userId)
	T.check("puzzle baru per permintaan", solution2 ~= nil)
	local _, payload2 = call("starwhale.lastPayload", userId)
	T.check("puzzle baru tanpa solusi", payload2.puzzle ~= nil and payload2.puzzle.solution == nil)

	-- Solusi yang benar.
	local applied = PipePuzzle.applyRotations({
		size = 5,
		tiles = payload2.puzzle.tiles,
		source = payload2.puzzle.source,
		target = payload2.puzzle.target,
	}, solution2)
	T.check("solusi hook menyelesaikan puzzle", applied ~= nil and PipePuzzle.isSolved(applied))
	T.check("submit benar diterima", StarwhaleService.submit(userId, solution2) == true)
	T.check("relayFixed true", data.starwhale.relayFixed == true)
	T.check("gear.compass = 1", data.gear.compass == 1)
	T.wait(0.5)
	local _, afterFix = call("starwhale.info", userId)
	T.check("tepat satu Star Compass", afterFix.compassTools == 1, afterFix.compassTools)
	T.check("submit kedua ditolak", StarwhaleService.submit(userId, solution2) == false)
	T.check(
		"puzzle baru ditolak setelah relay baik",
		StarwhaleService.requestPuzzle(userId) == false
	)
	local _, afterPayload = call("starwhale.lastPayload", userId)
	T.check("state relayFixed terkirim", afterPayload.relayFixed == true)

	-- ===== Penampakan =====
	T.check("tanpa kunjungan", select(2, call("starwhale.state")).active == false)
	local okForce, forceRes = call("starwhale.force", 5)
	T.check("force berhasil", okForce and forceRes.ok == true)
	local _, st = call("starwhale.state")
	T.check("kunjungan aktif zona 5", st.active == true and st.zone == 5, st.zone)
	T.check("tepat satu model paus bertag", st.models == 1 and count(Types.Tags.Starwhale) == 1)
	T.check("model paus ada", st.hasModel == true)
	T.check(
		"x paus 30..45 (nilai mutlak)",
		math.abs(st.x) >= CFG.laneXMin and math.abs(st.x) <= CFG.laneXMax,
		st.x
	)
	local zMid = (Layout.zoneZStart(5) + Layout.zoneZEnd(5)) / 2
	T.check("z paus di tengah zona", math.abs(st.z - zMid) <= CFG.zJitter + 0.01, st.z)
	T.check(
		"remaining ~ stayingSeconds",
		math.abs(st.remaining - CFG.stayingSeconds) < 3,
		st.remaining
	)
	T.check("force ganda ditolak", select(2, call("starwhale.force")).ok == false)
	local whalePos = Vector3.new(st.x, st.y, st.z)

	local _, p1 = call("starwhale.lastPayload", userId)
	T.check("payload Sighted untuk pemain berkompas", p1.phase == "Sighted" and p1.zone == 5)
	T.check(
		"remaining dikirim sebagai sisa detik",
		p1.remaining >= CFG.stayingSeconds - 3 and p1.remaining <= CFG.stayingSeconds
	)
	T.check(
		"target dikirim ke pemilik kompas",
		p1.target ~= nil and math.abs(p1.target[1] - st.x) < 0.01
	)
	-- Tanpa kompas: tidak ada target. (advance 5.1 memicu dorongan state 5 detik.)
	data.gear.compass = 0
	StarwhaleService.advance(5.1)
	local _, p2 = call("starwhale.lastPayload", userId)
	T.check("tanpa kompas tidak ada target", p2.target == nil and p2.phase == "Sighted")
	data.gear.compass = 1
	StarwhaleService.advance(5.1)
	local _, p3 = call("starwhale.lastPayload", userId)
	T.check("kompas dikembalikan: target ada lagi", p3.target ~= nil)

	-- ===== Found =====
	local oddSeedBase = select(2, call("starwhale.state")).id
	local odd = StarwhaleMath.oddPositions(
		StarwhaleMath.oddSeed(oddSeedBase, userId),
		{ whalePos.X, whalePos.Y, whalePos.Z }
	)
	T.check("3 posisi telur aneh", #odd == 3)
	local oddAgain = StarwhaleMath.oddPositions(
		StarwhaleMath.oddSeed(oddSeedBase, userId),
		{ whalePos.X, whalePos.Y, whalePos.Z }
	)
	T.check("posisi deterministik", odd[2][1] == oddAgain[2][1] and odd[3][3] == oddAgain[3][3])
	local bounds = StarwhaleMath.laneBounds(whalePos.Z)
	local validOdd = true
	for i, p in odd do
		if
			planar(whalePos, p) > CFG.oddRadius + 1e-6
			or p[1] < bounds.minX
			or p[1] > bounds.maxX
			or p[3] < bounds.minZ
			or p[3] > bounds.maxZ
			or p[2] ~= CFG.oddY
		then
			validOdd = false
		end
		for j = i + 1, 3 do
			if
				math.sqrt((p[1] - odd[j][1]) ^ 2 + (p[3] - odd[j][3]) ^ 2)
				< CFG.oddSpacing - 1e-6
			then
				validOdd = false
			end
		end
	end
	T.check("posisi telur aneh valid (radius, jarak, lane, lantai)", validOdd)

	-- Jauh dari paus: belum Found; collect ditolak.
	tp(Vector3.new(whalePos.X, 3, whalePos.Z - 85))
	T.wait(0.4)
	local _, farInfo = call("starwhale.info", userId)
	T.check("jauh dari paus: belum Found", farInfo.found == false)
	T.check("collect sebelum Found ditolak", StarwhaleService.collect(userId, 1) == false)
	T.check("hitPod sebelum selesai ditolak", StarwhaleService.hitPod(userId, 1) == false)

	-- Tanpa kompas dekat paus: tetap belum Found.
	data.gear.compass = 0
	tp(Vector3.new(whalePos.X, 3, whalePos.Z - 20))
	T.wait(0.4)
	T.check("tanpa kompas tidak Found", select(2, call("starwhale.info", userId)).found == false)
	data.gear.compass = 1

	-- Titik pijak dekat paus (<35) yang jauh (>14) dari semua telur aneh.
	local spot
	for _, offset in
		{
			{ 0, 20 },
			{ 0, -20 },
			{ 20, 0 },
			{ -20, 0 },
			{ 22, 22 },
			{ -22, -22 },
			{ 22, -22 },
			{ -22, 22 },
		}
	do
		local candidate = Vector3.new(whalePos.X + offset[1], 3, whalePos.Z + offset[2])
		local clear = candidate.X > bounds.minX - 5 and candidate.X < bounds.maxX + 5
		for _, p in odd do
			if dist3(candidate, p) <= 14 then
				clear = false
			end
		end
		if clear then
			spot = candidate
			break
		end
	end
	T.check("ada titik uji dekat paus", spot ~= nil)
	spot = spot or Vector3.new(whalePos.X, 3, whalePos.Z - 20)
	tp(spot)
	T.wait(0.5)
	local _, foundInfo = call("starwhale.info", userId)
	T.check("dalam 35 stud: Found", foundInfo.found == true)
	local _, fp = call("starwhale.lastPayload", userId)
	T.check(
		"payload Found: 0/3 dan 3 posisi",
		fp.phase == "Found" and fp.oddEggs == 0 and fp.oddEggsTotal == 3 and #fp.oddPositions == 3
	)
	T.check(
		"posisi payload = fungsi deterministik",
		math.abs(fp.oddPositions[1][1] - odd[1][1]) < 1e-6
			and math.abs(fp.oddPositions[3][3] - odd[3][3]) < 1e-6
	)

	-- ===== collect =====
	T.check("indeks 0 ditolak", StarwhaleService.collect(userId, 0) == false)
	T.check("indeks 4 ditolak", StarwhaleService.collect(userId, 4) == false)
	T.check("indeks 1.5 ditolak", StarwhaleService.collect(userId, 1.5) == false)
	T.check("indeks string ditolak", StarwhaleService.collect(userId, "1") == false)
	T.check("terlalu jauh ditolak", StarwhaleService.collect(userId, 1) == false)
	T.check(
		"collectValidator menolak 0/4",
		Check.args(Check.int(1, 3))(0) == false and Check.args(Check.int(1, 3))(4) == false
	)
	T.check("belum ada telur tercatat", data.starwhale.eggsFoundThisVisit == 0)

	tp(Vector3.new(odd[1][1], 3, odd[1][3]))
	T.check("collect 1 dekat: diterima", StarwhaleService.collect(userId, 1) == true)
	T.check("eggsFoundThisVisit = 1", data.starwhale.eggsFoundThisVisit == 1)
	T.check("collect duplikat ditolak", StarwhaleService.collect(userId, 1) == false)
	T.check(
		"collect 2 dari posisi telur 1 (jauh) ditolak",
		StarwhaleService.collect(userId, 2) == false
	)
	local _, c1 = call("starwhale.lastPayload", userId)
	T.check(
		"payload 1/3 dengan slot terambil kosong",
		c1.oddEggs == 1 and #c1.oddPositions[1] == 0 and #c1.oddPositions[2] == 3
	)
	T.check("belum ada pod sebelum 3/3", select(2, call("starwhale.state")).podsLeft == 0)

	tp(Vector3.new(odd[2][1], 3, odd[2][3]))
	T.check("collect 2", StarwhaleService.collect(userId, 2) == true)
	tp(Vector3.new(odd[3][1], 3, odd[3][3]))
	T.check("collect 3", StarwhaleService.collect(userId, 3) == true)
	local _, done = call("starwhale.info", userId)
	T.check("selesai 3/3", done.done == true and done.count == 3)
	local _, dp = call("starwhale.lastPayload", userId)
	T.check("payload Done 3/3", dp.phase == "Done" and dp.oddEggs == 3 and dp.oddPositions == nil)
	local _, st2 = call("starwhale.state")
	T.check("6 pod muncul", st2.podsLeft == CFG.podCount and st2.pods == CFG.podCount, st2.pods)
	local allHp = true
	for _, pod in CollectionService:GetTagged(Types.Tags.StardustPod) do
		if pod:GetAttribute(Types.Attr.PodHp) ~= 3 then
			allHp = false
		end
	end
	T.check("tiap pod HP 3", allHp)
	T.check("collect setelah selesai ditolak", StarwhaleService.collect(userId, 1) == false)

	-- ===== pod =====
	local function goPod(i: number)
		local _, pos = call("starwhale.podPos", i)
		if pos then
			tp(Vector3.new(pos[1], 3, pos[3] + 4))
		end
		return pos
	end
	goPod(1)
	local before = data.stardust
	local ok1, r1 = StarwhaleService.hitPod(userId, 1)
	T.check("pukulan 1: HP 2", ok1 and r1.hp == 2 and r1.broke == false)
	T.check("stardust belum berubah", data.stardust == before)
	local ok2, r2 = StarwhaleService.hitPod(userId, 1)
	T.check("pukulan 2: HP 1", ok2 and r2.hp == 1)
	local ok3, r3 = StarwhaleService.hitPod(userId, 1)
	T.check("pukulan 3 memecahkan pod", ok3 and r3.broke == true)
	T.check(
		"stardust 1..4 dibayar sekali ke pemukul",
		r3.stardust >= 1 and r3.stardust <= 4 and data.stardust == before + r3.stardust,
		data.stardust
	)
	T.check("pod hilang: 5 tersisa", select(2, call("starwhale.state")).pods == 5)
	T.check("pukulan ke pod pecah ditolak", StarwhaleService.hitPod(userId, 1) == false)
	T.check("stardust tidak berubah lagi", data.stardust == before + r3.stardust)

	-- Pod jauh ditolak.
	local farOk = StarwhaleService.hitPod(userId, 4)
	T.check("pod jauh (>reach) ditolak", farOk == false)

	for _, i in { 2, 3 } do
		goPod(i)
		StarwhaleService.hitPod(userId, i)
		StarwhaleService.hitPod(userId, i)
		StarwhaleService.hitPod(userId, i)
	end
	local _, limInfo = call("starwhale.info", userId)
	T.check("3 pod dipecahkan", limInfo.cracked == 3, limInfo.cracked)
	local afterThree = data.stardust
	goPod(4)
	T.check("batas 3 pod per pemain", StarwhaleService.hitPod(userId, 4) == false)
	T.check("stardust sama setelah batas", data.stardust == afterThree)
	T.check("3 pod tersisa di dunia", select(2, call("starwhale.state")).pods == 3)
	local stardustEarned = afterThree - startStardust
	T.check("total stardust 3..12", stardustEarned >= 3 and stardustEarned <= 12, stardustEarned)

	-- ===== paus pergi =====
	StarwhaleService.advance(CFG.stayingSeconds + 5)
	local _, gone = call("starwhale.state")
	T.check(
		"paus hilang",
		gone.active == false and gone.models == 0 and count(Types.Tags.Starwhale) == 0
	)
	T.check("pod hilang", gone.pods == 0 and count(Types.Tags.StardustPod) == 0)
	local _, idle = call("starwhale.lastPayload", userId)
	T.check(
		"state Idle setelah pergi",
		idle.phase == "Idle" and idle.remaining == 0 and idle.target == nil
	)
	T.check("hitPod tanpa kunjungan ditolak", StarwhaleService.hitPod(userId, 5) == false)

	-- Kunjungan baru mereset progres.
	local previousId = data.starwhale.lastVisitId
	StarwhaleService.force(7)
	local _, st3 = call("starwhale.state")
	T.check("kunjungan baru id lebih besar", st3.id > previousId, st3.id)
	T.check("lastVisitId diperbarui", data.starwhale.lastVisitId == st3.id)
	T.check("eggsFoundThisVisit reset", data.starwhale.eggsFoundThisVisit == 0)
	local _, newInfo = call("starwhale.info", userId)
	T.check(
		"progres kunjungan baru kosong",
		newInfo.found == false and newInfo.count == 0 and newInfo.cracked == 0
	)
	local _, withTarget = call("starwhale.lastPayload", userId)
	T.check(
		"kunjungan baru: Sighted zona 7",
		withTarget.phase == "Sighted" and withTarget.zone == 7
	)
	T.check("invariants bersih saat paus ada", #InvariantChecker.check() == 0)
	StarwhaleService.endVisit()
	T.check("endVisit membersihkan", count(Types.Tags.Starwhale) == 0)

	-- ===== trade =====
	tp(Vector3.new(0, 3, Layout.spawnPad.z))
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
	local function setDust(v: number)
		CurrencyService.set(userId, "stardust", v)
	end

	T.check(
		"harga: 40/15/15/25",
		CFG.offerById.orbital.price == 40
			and CFG.offerById.lucky.price == 15
			and CFG.offerById.speed.price == 15
			and CFG.offerById.growth.price == 25
	)
	T.check("Limited tidak ada", CFG.offerById.limited == nil and #CFG.offers == 4)

	setDust(14)
	T.check("lucky 14 Stardust ditolak", StarwhaleService.trade(userId, "lucky") == false)
	T.check("saldo utuh setelah ditolak", data.stardust == 14 and data.boosts.lucky2xUntil == 0)
	setDust(100)
	T.check(
		"penawaran tak dikenal ditolak",
		StarwhaleService.trade(userId, "limited_calf") == false and data.stardust == 100
	)

	local now = Clock.now()
	T.check("lucky diterima", StarwhaleService.trade(userId, "lucky") == true)
	T.check("lucky -15", data.stardust == 85)
	T.check(
		"lucky2xUntil = now+600",
		math.abs(data.boosts.lucky2xUntil - (now + 600)) <= 3,
		data.boosts.lucky2xUntil
	)
	T.check(
		"speed diterima: -15 dan +300",
		StarwhaleService.trade(userId, "speed") == true
			and data.stardust == 70
			and math.abs(data.boosts.speed2xUntil - (now + 300)) <= 3
	)
	T.check(
		"growth diterima: -25 dan +600",
		StarwhaleService.trade(userId, "growth") == true
			and data.stardust == 45
			and math.abs(data.boosts.growth2xUntil - (now + 600)) <= 3
	)
	data.boosts.lucky2xUntil = Clock.now() + 5000
	setDust(100)
	StarwhaleService.trade(userId, "lucky")
	T.check("boost tidak memendek (max)", data.boosts.lucky2xUntil >= Clock.now() + 4990)

	-- Orbital.
	local eggUid = placeEgg("twegg1", 12, -10)
	setDust(39)
	T.check(
		"orbital 39 ditolak",
		StarwhaleService.trade(userId, "orbital", eggUid) == false and #data.eggs[eggUid].muts == 0
	)
	setDust(100)
	T.check(
		"orbital tanpa target ditolak",
		StarwhaleService.trade(userId, "orbital") == false and data.stardust == 100
	)
	T.check(
		"orbital target tak ada ditolak",
		StarwhaleService.trade(userId, "orbital", "nonexist") == false and data.stardust == 100
	)
	T.check("orbital diterima", StarwhaleService.trade(userId, "orbital", eggUid) == true)
	T.check(
		"orbital -40 dan mutasi tertulis",
		data.stardust == 60 and table.find(data.eggs[eggUid].muts, "Orbital") ~= nil
	)
	T.check(
		"orbital duplikat ditolak",
		StarwhaleService.trade(userId, "orbital", eggUid) == false and data.stardust == 60
	)

	local eggB = placeEgg("twegg2", -12, -10)
	GrowthService.setFrozen(userId, eggB, true)
	T.check(
		"orbital telur beku ditolak",
		StarwhaleService.trade(userId, "orbital", eggB) == false and data.stardust == 60
	)
	GrowthService.setFrozen(userId, eggB, false)
	data.eggs[eggB].loc = "pocket"
	T.check(
		"orbital telur kantong ditolak",
		StarwhaleService.trade(userId, "orbital", eggB) == false and data.stardust == 60
	)
	data.eggs[eggB].loc = "placed"
	data.eggs[eggB].muts = { "Pearl", "Amber", "Starlit" }
	T.check(
		"orbital telur penuh ditolak",
		StarwhaleService.trade(userId, "orbital", eggB) == false and data.stardust == 60
	)
	data.eggs[eggB].muts = {}
	T.check(
		"orbital telur lain diterima",
		StarwhaleService.trade(userId, "orbital", eggB) == true and data.stardust == 20
	)
	local enumOk = Check.args(Check.enum(CFG.offerIds), Check.optional(Check.uid))
	T.check(
		"validator trade",
		enumOk("orbital", "abc")
			and enumOk("lucky")
			and not enumOk("hack")
			and not enumOk("lucky", "bad uid!")
	)

	-- ===== pembersihan =====
	StarwhaleService.endVisit()
	DataService.wipe(userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	T.check(
		"wipe: relay dan compass reset",
		data.starwhale.relayFixed == false and data.gear.compass == 0 and data.stardust == 0
	)
	T.wait(0.3)
	local _, finalInfo = call("starwhale.info", userId)
	T.check("wipe: Star Compass dilepas", finalInfo.compassTools == 0, finalInfo.compassTools)
	T.check(
		"dunia bersih",
		count(Types.Tags.Starwhale) == 0
			and count(Types.Tags.StardustPod) == 0
			and Actors.getRoot(userId) ~= nil
	)
	local inv = InvariantChecker.check()
	T.check("invariants bersih", #inv == 0, table.concat(inv, "; "))
end
