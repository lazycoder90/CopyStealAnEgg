--!nonstrict
-- Skenario uji Fase 1 (cepat): peta, telur dunia, grab/drop, place + semua pesan galat, hatch, pet.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "CoreLoop")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local Layout = require(Shared.Config.Layout)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)
local GrowthService = require(Server.Services.GrowthService)
local HatchService = require(Server.Services.HatchService)
local PetService = require(Server.Services.PetService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId

	local function teleport(pos: Vector3)
		require(Server.Systems.TestBridge).teleport(userId, pos + Vector3.new(0, 4, 0))
		T.wait(0.15)
	end
	local function grabNearest(zone: number?)
		local root = Actors.getRoot(userId)
		local best, bestDist
		for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
			local uid = model:GetAttribute(Types.Attr.EggUid)
			local entity = uid and EggSpawnService.getEntity(uid)
			if entity and entity.state == "Occupied" and (zone == nil or entity.zone == zone) then
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
		local ok, err = CarryService.tryPickupWorld(userId, best.uid)
		return ok, err, best
	end

	-- Mulai bersih: data baru, plot baru.
	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	T.check("data direset (tanpa telur/pet)", next(data.eggs) == nil and next(data.pets) == nil)

	-- ===== Peta & dunia =====
	local plot = PlotService.getPlot(userId)
	T.check("pemain punya Coop", plot ~= nil)
	T.check("8 Coop ada", #workspace[Types.Names.Plots]:GetChildren() == Layout.plotCount)
	T.check("Hearth Line ada", workspace[Types.Names.Map]:FindFirstChild("HearthLine") ~= nil)
	local stats = EggSpawnService.stats()
	T.check("telur dunia terbentuk (12 zona x 11 sarang)", stats.Occupied == 132, stats.Occupied)
	local inv = InvariantChecker.check()
	T.check("invarian bersih di awal", #inv == 0, table.concat(inv, " | "))

	-- ===== Grab / drop =====
	local ok, err, egg1 = grabNearest(1)
	T.check("grab telur berhasil", ok == true, err)
	T.check("sedang membawa", CarryService.isCarrying(userId))
	T.check(
		"model telur menempel di karakter",
		egg1 and egg1.model.Parent == Actors.getCharacter(userId)
	)
	T.check("nest berstatus Carried", EggSpawnService.stats().Carried == 1)

	local ok2, err2 = CarryService.tryPickupWorld(userId, egg1.uid)
	T.check(
		"grab kedua ditolak (sudah membawa)",
		ok2 == false and err2 == Eggs.messages.alreadyCarrying,
		err2
	)

	-- Place dari lane (jauh dari Coop)
	local okFar, msgFar = PlacementService.place(userId, Actors.getRoot(userId).Position)
	T.check(
		"place jauh dari Coop -> tooFar",
		okFar == false and msgFar == Eggs.messages.tooFar,
		msgFar
	)

	CarryService.drop(userId, "dropped")
	T.check("drop: tidak membawa lagi", not CarryService.isCarrying(userId))
	T.check("drop: telur berstatus Dropped", EggSpawnService.stats().Dropped == 1)
	T.check(
		"drop: model kembali ke WorldEggs",
		egg1.model.Parent == workspace[Types.Names.WorldEggs]
	)

	-- Ambil lagi dari kondisi Dropped
	teleport(EggSpawnService.entityPosition(egg1) + Vector3.new(3, 0, 0))
	local ok3, err3 = CarryService.tryPickupWorld(userId, egg1.uid)
	T.check("grab ulang telur yang jatuh", ok3 == true, err3)

	-- ===== Place di Coop =====
	local function localToWorld(x, z)
		return PlotService.localToWorld(plot, x, z)
	end
	teleport(localToWorld(0, 0))

	local okR, msgR = PlacementService.place(
		userId,
		localToWorld(Layout.plotSpawnLocal.x, Layout.plotSpawnLocal.z)
	)
	T.check("place di area spawn -> badSpot", okR == false and msgR == Eggs.messages.badSpot, msgR)
	local okE, msgE = PlacementService.place(userId, localToWorld(Layout.plotSize / 2 - 1, 0))
	T.check("place di tepi plot -> badSpot", okE == false and msgE == Eggs.messages.badSpot, msgE)

	local okP, msgP = PlacementService.place(userId, localToWorld(0, -5))
	T.check("place valid berhasil", okP == true, msgP)
	T.check("tidak membawa setelah place", not CarryService.isCarrying(userId))
	data = DataService.getByUserId(userId)
	local placedUid
	for uid, e in data.eggs do
		placedUid = uid
		T.check("telur masuk profil placed", e.loc == "placed" and e.pos ~= nil)
		T.check(
			"telur pertama tumbuh <= 3 detik (tutorial)",
			e.growTotal <= Eggs.tutorialGrowSeconds,
			e.growTotal
		)
	end
	T.check(
		"model telur placed dibuat",
		placedUid and GrowthService.getModel(userId, placedUid) ~= nil
	)
	T.check("nest asal kosong (entity dihancurkan)", egg1.state == "Destroyed")

	-- Telur kedua terlalu dekat
	local ok4 = grabNearest(1)
	T.check("grab telur ke-2", ok4 == true)
	teleport(localToWorld(0, 0))
	local okC, msgC = PlacementService.place(userId, localToWorld(0 + Eggs.placeMinSpacing - 2, -5))
	T.check(
		"place terlalu dekat -> tooClose",
		okC == false and msgC == Eggs.messages.tooClose,
		msgC
	)
	T.check("telur tetap dibawa setelah gagal", CarryService.isCarrying(userId))
	local okP2, msgP2 = PlacementService.place(userId, localToWorld(20, -5))
	T.check("place telur ke-2 valid", okP2 == true, msgP2)

	-- Isi sampai penuh (slot level 1 = 4), lalu telur ke-5 ditolak
	local slots = 4
	local positions = { { -20, -5 }, { 20, 12 } }
	for i = 1, slots - 2 do
		local g = grabNearest(1)
		T.check("grab telur isi-" .. i, g == true)
		teleport(localToWorld(0, 0))
		local p = positions[i]
		local okI, msgI = PlacementService.place(userId, localToWorld(p[1], p[2]))
		T.check("place isi-" .. i, okI == true, msgI)
	end
	local g5 = grabNearest(1)
	T.check("grab telur ke-5", g5 == true)
	teleport(localToWorld(0, 0))
	local okF, msgF = PlacementService.place(userId, localToWorld(-20, 22))
	T.check("Coop penuh -> coopFull", okF == false and msgF == Eggs.messages.coopFull, msgF)
	CarryService.drop(userId, "dropped")

	-- ===== Hatch =====
	data = DataService.getByUserId(userId)
	local firstUid = placedUid
	local okH, errH = HatchService.hatch(userId, firstUid)
	T.check("hatch sebelum siap ditolak", okH == false, errH)
	local model = GrowthService.getModel(userId, firstUid)
	local prompt = model.PrimaryPart:FindFirstChild(Types.Names.HatchPrompt)
	T.check("prompt Hatch nonaktif saat belum siap", prompt ~= nil and prompt.Enabled == false)
	game:GetService("ServerStorage").TestBridge:Invoke("growth.advance", userId, firstUid, 100000)
	T.check("prompt Hatch aktif saat siap", prompt.Enabled == true)
	T.check("atribut Ready aktif", model:GetAttribute(Types.Attr.Ready) == true)
	local okH2, payload = HatchService.hatch(userId, firstUid)
	T.check("hatch berhasil", okH2 == true, payload)
	data = DataService.getByUserId(userId)
	T.check("telur hilang dari profil", data.eggs[firstUid] == nil)
	T.check(
		"model telur dihapus",
		GrowthService.getModel(userId, firstUid) == nil and (model == nil or model.Parent == nil)
	)
	T.check("pet masuk inventaris", PetService.petCount(data) == 1)
	T.check("pet otomatis dipasang", PetService.equippedCount(data) == 1)
	T.check("stats.hatched = 1", data.stats.hatched == 1)
	T.check("Index menandai spesies", payload and data.index.found[payload.speciesId] == true)
	T.check(
		"payload reveal lengkap",
		payload and payload.income > 0 and payload.name ~= nil and payload.rarity >= 1
	)
	local plotPets = plot[Types.Names.PlotPets]
	T.check("folder ActivePets berisi 1 pet", #plotPets:GetChildren() == 1, #plotPets:GetChildren())

	-- Equip/unequip
	local petUid = payload.petUid
	T.check("unequip", PetService.unequip(userId, petUid) == true and #plotPets:GetChildren() == 0)
	T.check("equip", PetService.equip(userId, petUid) == true and #plotPets:GetChildren() == 1)

	-- ===== Invarian =====
	local inv2 = InvariantChecker.check()
	T.check("invarian bersih di akhir", #inv2 == 0, table.concat(inv2, " | "))
end
