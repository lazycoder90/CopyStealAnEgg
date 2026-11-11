--!nonstrict
-- Skenario uji Wave 4: Egg Reset global (Carried/Dropped utuh), aturan pengumuman (buffer, batas, boot).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "EggReset")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local GameEvents = require(Server.Systems.GameEvents)
local TestBridge = require(Server.Systems.TestBridge)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)

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
	local function teleport(pos: Vector3)
		TestBridge.teleport(userId, pos + Vector3.new(0, 4, 0))
		T.wait(0.15)
	end
	local function grabNearest(zone: number)
		local root = Actors.getRoot(userId)
		local best, bestDist
		for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
			local uid = model:GetAttribute(Types.Attr.EggUid)
			local entity = uid and EggSpawnService.getEntity(uid)
			if entity and entity.state == "Occupied" and entity.zone == zone then
				local d = (model:GetPivot().Position - root.Position).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = entity, d
				end
			end
		end
		if not best then
			return nil
		end
		teleport(EggSpawnService.entityPosition(best) + Vector3.new(4, 0, 0))
		local ok = CarryService.tryPickupWorld(userId, best.uid)
		return ok and best or nil
	end
	local function liveUids()
		local set = {}
		for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
			local uid = model:GetAttribute(Types.Attr.EggUid)
			if uid then
				set[uid] = true
			end
		end
		return set
	end

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik

	local prevStart = call("reset.setStartedAt", os.clock() - 100)
	local prevRemaining = call("reset.remaining")
	call("reset.clearLog")

	-- ===== Reset: Occupied diganti, Carried/Dropped utuh =====
	local eggA = grabNearest(1)
	T.check("grab telur A", eggA ~= nil)
	CarryService.drop(userId, "dropped")
	local eggB = grabNearest(1)
	T.check("grab telur B", eggB ~= nil)
	local before = EggSpawnService.stats()
	T.check("1 Carried 1 Dropped sebelum reset", before.Carried == 1 and before.Dropped == 1)
	local oldUids = liveUids()

	local count = call("reset.now")
	local after = EggSpawnService.stats()
	T.check(
		"reset me-roll semua nest selain Carried/Dropped",
		count == before.Occupied + before.Empty,
		count
	)
	T.check(
		"A tetap Dropped",
		EggSpawnService.getEntity(eggA.uid) == eggA and eggA.state == "Dropped"
	)
	T.check(
		"B tetap Carried",
		EggSpawnService.getEntity(eggB.uid) == eggB and eggB.state == "Carried"
	)
	T.check(
		"statistik nest sama",
		after.Carried == 1 and after.Dropped == 1 and after.Empty == 0,
		after.Occupied
	)
	local survivors = 0
	for uid in liveUids() do
		if oldUids[uid] and uid ~= eggA.uid and uid ~= eggB.uid then
			survivors += 1
		end
	end
	T.check("semua telur Occupied diganti", survivors == 0, survivors)
	T.check("timer reset di-restart", call("reset.remaining") > 590)

	local log = call("reset.log")
	T.check("pengumuman ALL EGGS RESET!", log[1] == "ALL EGGS RESET!", log[1])
	T.wait(1.4)
	log = call("reset.log")
	local spawnLines = 0
	for _, line in log do
		if string.find(line, " Egg spawned in ", 1, true) then
			spawnLines += 1
		end
	end
	T.check("maksimal 6 pengumuman spawn per batch", spawnLines <= 6, spawnLines)

	CarryService.drop(userId, "dropped")
	EggSpawnService.returnToNest(eggA)
	EggSpawnService.returnToNest(eggB)

	-- ===== Aturan pengumuman (event sintetis) =====
	local function spawnEvent(rarity: number)
		GameEvents.EggSpawned:Fire({
			zone = 1,
			speciesId = "clover_bunny",
			rarity = rarity,
			grand = false,
			nestId = "test",
		})
	end
	call("reset.clearLog")
	for _, rarity in { 5, 1, 6, 10, 4, 7, 5, 9, 8, 6, 5 } do
		spawnEvent(rarity)
	end
	T.wait(0.3)
	T.check("buffer: belum ada yang terkirim sebelum 1 detik", #call("reset.log") == 0)
	T.wait(1.2)
	log = call("reset.log")
	T.check("batas 6 per batch", #log == 6, #log)
	local order = { "Primordial", "Timeless", "Void", "Astral", "Mythic", "Mythic" }
	for i, name in order do
		T.check(
			`urutan rarity {i}: {name}`,
			log[i] ~= nil and string.find(log[i], name, 1, true) ~= nil,
			log[i]
		)
	end
	T.check(
		"format kalimat",
		log[1] ~= nil
			and string.find(log[1], "^A Primordial Clover Bunny Egg spawned in Mossy Meadow!$")
				~= nil,
		log[1]
	)

	-- rarity non-announce tidak diumumkan
	call("reset.clearLog")
	spawnEvent(1)
	spawnEvent(4)
	T.wait(1.4)
	T.check("rarity < Legendary tidak diumumkan", #call("reset.log") == 0)

	-- jendela boot: spawn dalam 20 detik pertama diabaikan
	call("reset.setStartedAt", os.clock() - 1)
	spawnEvent(10)
	T.wait(1.4)
	T.check("spawn boot tidak diumumkan", #call("reset.log") == 0)
	call("reset.setStartedAt", os.clock() - 100)

	-- hatch langka diumumkan
	GameEvents.EggHatched:Fire({
		userId = -99,
		petUid = "x",
		speciesId = "clover_bunny",
		rarity = 5,
		zone = 1,
		isNew = true,
	})
	GameEvents.EggHatched:Fire({
		userId = -99,
		petUid = "y",
		speciesId = "clover_bunny",
		rarity = 4,
		zone = 1,
		isNew = true,
	})
	T.wait(0.2)
	log = call("reset.log")
	T.check("hanya hatch announce-rarity diumumkan", #log == 1, #log)
	T.check(
		"kalimat hatch",
		log[1] ~= nil and string.find(log[1], " hatched a Legendary Clover Bunny!", 1, true) ~= nil,
		log[1]
	)
	T.check("rarity 5 = Legendary", Rarities.get(5).announce == true)

	-- ===== Hitung mundur mengikuti waktu-game =====
	call("reset.setRemaining", 500)
	T.wait(2.3)
	local rem = call("reset.remaining")
	T.check("timer berkurang", rem < 499 and rem > 490, rem)

	call("reset.setRemaining", prevRemaining)
	call("reset.setStartedAt", prevStart)
	call("reset.clearLog")
	DataService.wipe(userId)
	T.wait(1.2)
end
