--!nonstrict
-- Skenario uji siklus hidup Fase 1: income, rejoin (data + model + pet), keluar saat membawa telur.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Life")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local PetMath = require(Shared.Logic.PetMath)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)
local GrowthService = require(Server.Services.GrowthService)
local IncomeService = require(Server.Services.IncomeService)
local PetService = require(Server.Services.PetService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge

	local function teleport(pos: Vector3)
		require(Server.Systems.TestBridge).teleport(userId, pos + Vector3.new(0, 4, 0))
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
		teleport(EggSpawnService.entityPosition(best) + Vector3.new(4, 0, 0))
		return CarryService.tryPickupWorld(userId, best.uid)
	end

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local plot = PlotService.getPlot(userId)
	local function localToWorld(x, z)
		return PlotService.localToWorld(plot, x, z)
	end

	-- ===== Income =====
	local petUid = bridge:Invoke("pets.give", userId, "pebble_chick", 1.2).result
	T.check("pet uji dibuat", petUid ~= nil)
	local okEq, errEq = PetService.equip(userId, petUid)
	T.check("pet uji dipasang", okEq == true, errEq)
	local data = DataService.getByUserId(userId)
	local expected = PetMath.petIncome("pebble_chick", 1.2, {})
	T.check(
		"income/s sesuai PetMath",
		math.abs(IncomeService.compute(userId, data) - expected) < 1e-9,
		expected
	)
	T.check("income $3/s untuk Pebble Chick", math.abs(expected - 3) < 1e-9, expected)

	local cash0 = data.cash
	T.wait(3.3)
	data = DataService.getByUserId(userId)
	local gained = data.cash - cash0
	T.check("cash bertambah sesuai income (~9)", gained >= 6 and gained <= 13, gained)
	T.check("lastIncomePerSec tercatat", math.abs(data.lastIncomePerSec - expected) < 1e-9)
	T.check("totalEarned bertambah", data.totalEarned >= gained)

	-- Slot equip: pet ke-2 melebihi 3 slot tidak bisa
	local uids = { petUid }
	for _ = 1, 3 do
		table.insert(uids, bridge:Invoke("pets.give", userId, "moss_pup", 2).result)
	end
	local okAll = true
	local lastErr
	for i = 2, 4 do
		local ok, err = PetService.equip(userId, uids[i])
		if i <= 3 then
			okAll = okAll and ok == true
		else
			lastErr = err
			okAll = okAll and ok == false
		end
	end
	T.check("slot equip dibatasi 3", okAll, lastErr)
	PetService.equipBest(userId)
	data = DataService.getByUserId(userId)
	T.check("Equip Best mengisi tepat 3 slot", PetService.equippedCount(data) == 3)
	T.check(
		"Equip Best memilih pet terkuat (moss_pup > pebble_chick)",
		data.pets[petUid].eq == false
	)

	-- ===== Rejoin: telur placed dan pet bertahan =====
	grabNearest(1)
	teleport(localToWorld(0, 0))
	T.check("place sebelum rejoin", PlacementService.place(userId, localToWorld(0, -5)) == true)
	data = DataService.getByUserId(userId)
	local eggUidBefore
	for uid in data.eggs do
		eggUidBefore = uid
	end
	local function stable(d)
		local eggs, pets = {}, {}
		for uid, e in d.eggs do
			eggs[uid] =
				`{e.id}|{e.kg}|{e.loc}|{e.pos and e.pos.x}|{e.pos and e.pos.z}|{e.growTotal}`
		end
		for uid, p in d.pets do
			pets[uid] = `{p.id}|{p.kg}|{p.g}|{table.concat(p.muts, ",")}|{p.eq}|{p.lock}`
		end
		local function flat(t)
			local keys = {}
			for k in t do
				table.insert(keys, k)
			end
			table.sort(keys)
			local out = {}
			for _, k in keys do
				table.insert(out, k .. "=" .. t[k])
			end
			return table.concat(out, ";")
		end
		local found = {}
		for k in d.index.found do
			found[k] = "1"
		end
		return flat(eggs)
			.. "#"
			.. flat(pets)
			.. "#"
			.. flat(found)
			.. "#"
			.. tostring(d.stats.hatched)
			.. "#"
			.. tostring(d.equipSlots)
	end
	local stableBefore = stable(DataService.getByUserId(userId))
	local rejoined = bridge:Invoke("lifecycle.simulateRejoin", userId)
	T.check("simulateRejoin berhasil", rejoined.ok and rejoined.result == true)
	T.wait(1.2)
	local stableAfter = stable(DataService.getByUserId(userId))
	T.check(
		"telur, pet, Index, statistik identik setelah rejoin",
		stableBefore == stableAfter,
		`{stableBefore} VS {stableAfter}`
	)
	plot = PlotService.getPlot(userId)
	T.check("Coop dibagikan lagi", plot ~= nil)
	T.check("model telur dibangun ulang", GrowthService.getModel(userId, eggUidBefore) ~= nil)
	T.check("pet aktif tampil lagi di Coop", #plot[Types.Names.PlotPets]:GetChildren() == 3)
	T.check("hanya 1 model telur (tidak ganda)", bridge:Invoke("growth.models", userId).result == 1)

	-- ===== Keluar saat membawa telur: telur kembali ke sarang =====
	local before = EggSpawnService.stats()
	local okG = grabNearest(1)
	T.check("grab sebelum keluar", okG == true)
	T.check("1 telur dibawa", EggSpawnService.stats().Carried == 1)
	bridge:Invoke("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	local after = EggSpawnService.stats()
	T.check("tidak ada telur yang dibawa setelah keluar", after.Carried == 0, after.Carried)
	T.check(
		"telur kembali ke sarang (jumlah Occupied sama)",
		after.Occupied == before.Occupied,
		`{before.Occupied} -> {after.Occupied}`
	)
	T.check("pemain tidak membawa apa pun", not CarryService.isCarrying(userId))

	-- Rejoin berulang tidak membocorkan model
	for _ = 1, 5 do
		bridge:Invoke("lifecycle.simulateRejoin", userId)
		T.wait(0.2)
	end
	T.check(
		"model telur tetap 1 setelah 5x rejoin",
		bridge:Invoke("growth.models", userId).result == 1
	)
	T.check(
		"folder Eggs plot berisi 1 model",
		#PlotService.getPlot(userId)[Types.Names.PlotEggs]:GetChildren() == 1
	)

	-- ===== Egg Reset =====
	local s0 = EggSpawnService.stats()
	local expectedReset = s0.Occupied + s0.Empty
	local resetCount = EggSpawnService.resetAll()
	T.check(
		"resetAll me-roll semua sarang Occupied/Empty",
		resetCount == expectedReset,
		`{resetCount} vs {expectedReset}`
	)
	local s1 = EggSpawnService.stats()
	T.check(
		"setelah reset: Occupied naik ke total, Carried/Dropped tak tersentuh",
		s1.Occupied == expectedReset and s1.Dropped == s0.Dropped and s1.Carried == s0.Carried
	)

	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
