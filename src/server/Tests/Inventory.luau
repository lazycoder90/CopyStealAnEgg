--!nonstrict
-- Skenario uji Inventaris: pocket/place, kapasitas 15, progress terjaga, aturan penempatan,
-- telur kantong tidak tumbuh, simulateRejoin, invarian.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Inventory")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)

local Actors = require(Server.Systems.Actors)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local TestBridge = require(Server.Systems.TestBridge)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local InventoryService = require(Server.Services.InventoryService)
local PlotService = require(Server.Services.PlotService)
local StateReplicator = require(Server.Services.StateReplicator)

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local SPECIES = "moss_pup"

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true
	data.penLevel = 1
	data.penLevel = 11 -- 14 slot Coop untuk uji (nilai sah menurut invarian)

	local plot = PlotService.getPlot(userId)
	local function worldAt(lx: number, lz: number): Vector3
		return PlotService.localToWorld(plot, lx, lz)
	end
	local function standAt(lx: number, lz: number)
		local p = worldAt(lx, lz)
		TestBridge.teleport(userId, p + Vector3.new(0, 4, 0))
		T.wait(0.15)
		return p
	end
	local function addPlaced(lx: number, lz: number, progress: number)
		local uid = newUid()
		data.eggs[uid] = {
			id = SPECIES,
			kg = 2,
			muts = {},
			growTotal = 1000,
			progress = progress,
			loc = "placed",
			pos = { x = lx, z = lz },
			t = 0,
		}
		StateReplicator.set(userId, `eggs.{uid}`, data.eggs[uid])
		GrowthService.ensureModel(userId, uid)
		return uid
	end

	-- ===== Pocket =====
	local a = addPlaced(-15, -5, 123)
	T.check("model ada sebelum pocket", GrowthService.getModel(userId, a) ~= nil)
	local ok, err = InventoryService.pocket(userId, a)
	T.check("pocket berhasil", ok == true, err)
	T.check(
		"loc pocket, pos nil, progress terjaga",
		data.eggs[a].loc == "pocket" and data.eggs[a].pos == nil and data.eggs[a].progress == 123
	)
	T.check("model dihapus", GrowthService.getModel(userId, a) == nil)
	T.check("pocketCount 1", InventoryService.pocketCount(data) == 1)
	ok = InventoryService.pocket(userId, a)
	T.check("pocket telur yang sudah di kantong ditolak", ok == false)
	ok = InventoryService.pocket(userId, "tidak_ada")
	T.check("pocket uid tidak dikenal ditolak", ok == false)

	-- Telur beku tidak bisa dikantongi
	local f = addPlaced(15, -5, 5)
	GrowthService.setFrozen(userId, f, true)
	ok = InventoryService.pocket(userId, f)
	T.check("telur beku tidak bisa dikantongi", ok == false and data.eggs[f].loc == "placed")
	GrowthService.setFrozen(userId, f, false)
	InventoryService.pocket(userId, f)

	-- Telur kantong tidak tumbuh
	local before = data.eggs[a].progress
	T.wait(2.3)
	T.check("telur kantong tidak tumbuh", data.eggs[a].progress == before)
	InvariantChecker.check()

	-- ===== Kapasitas 15 =====
	local fillers = {}
	while InventoryService.pocketCount(data) < Eggs.pocketCapacity do
		local uid = newUid()
		data.eggs[uid] = {
			id = SPECIES,
			kg = 1,
			muts = {},
			growTotal = 100,
			progress = 0,
			loc = "pocket",
			t = 0,
		}
		table.insert(fillers, uid)
	end
	T.check("kantong penuh 15", InventoryService.pocketCount(data) == Eggs.pocketCapacity)
	local extra = addPlaced(0, -5, 1)
	ok, err = InventoryService.pocket(userId, extra)
	T.check("kapasitas 15 ditegakkan", ok == false and data.eggs[extra].loc == "placed", err)
	for _, uid in fillers do
		data.eggs[uid] = nil
	end
	T.check("kantong kembali 2", InventoryService.pocketCount(data) == 2)

	-- ===== Place =====
	-- jauh dari Coop: ditolak
	TestBridge.teleport(userId, Vector3.new(0, 4, 40))
	T.wait(0.15)
	ok, err = InventoryService.place(userId, a, worldAt(0, 0))
	T.check("tooFar ditolak", ok == false and err == Eggs.messages.tooFar, err)
	T.check("telur tetap di kantong", data.eggs[a] ~= nil and data.eggs[a].loc == "pocket")

	-- titik terlarang (spawn point lokal 0,24)
	standAt(0, 24)
	ok, err = InventoryService.place(userId, a, worldAt(0, 24))
	T.check("badSpot ditolak", ok == false and err == Eggs.messages.badSpot, err)

	-- terlalu dekat dengan telur placed (extra di 0,-5)
	standAt(0, 0)
	ok, err = InventoryService.place(userId, a, worldAt(2, -5))
	T.check("tooClose ditolak", ok == false and err == Eggs.messages.tooClose, err)

	-- penempatan sah di lokasi kosong
	standAt(-20, 5)
	ok, err = InventoryService.place(userId, a, worldAt(-20, 5))
	T.check("place sah", ok == true, err)
	T.check(
		"progress terjaga setelah place",
		data.eggs[a] ~= nil and data.eggs[a].progress == 123 and data.eggs[a].loc == "placed"
	)
	T.check("pos lokal terisi", data.eggs[a] and data.eggs[a].pos ~= nil)
	T.check("model ada setelah place", GrowthService.getModel(userId, a) ~= nil)
	T.check("pocketCount 1", InventoryService.pocketCount(data) == 1)

	-- coopFull
	data.penLevel = 1
	local placedNow = 0
	for _, egg in data.eggs do
		if egg.loc == "placed" then
			placedNow += 1
		end
	end
	local slots = require(Shared.Config.Progression).eggSlotsFor(data.penLevel, 0)
	local filler = {}
	local idx = 0
	while placedNow < slots do
		idx += 1
		table.insert(filler, addPlaced(-30 + idx * 8, 30, 0))
		placedNow += 1
	end
	local pocketUid
	for uid, egg in data.eggs do
		if egg.loc == "pocket" then
			pocketUid = uid
		end
	end
	standAt(20, 5)
	ok, err = InventoryService.place(userId, pocketUid, worldAt(20, 5))
	T.check("coopFull ditolak", ok == false and err == Eggs.messages.coopFull, err)
	for _, uid in filler do
		GrowthService.removeModel(userId, uid)
		data.eggs[uid] = nil
		StateReplicator.set(userId, `eggs.{uid}`, nil)
	end

	-- ===== simulateRejoin menjaga telur kantong =====
	data.penLevel = 11
	T.check("pemain punya karakter", Actors.getRoot(userId) ~= nil)
	local pocketBefore = InventoryService.pocketCount(data)
	local progBefore = data.eggs[pocketUid].progress
	local rejoin = DataService.simulateRejoin(userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	T.check("rejoin berhasil", rejoin == true)
	T.check(
		"telur kantong tetap ada setelah rejoin",
		data ~= nil
			and InventoryService.pocketCount(data) == pocketBefore
			and data.eggs[pocketUid] ~= nil
			and data.eggs[pocketUid].progress == progBefore
	)
	T.check(
		"telur kantong tanpa model setelah rejoin",
		GrowthService.getModel(userId, pocketUid) == nil
	)

	-- Hook TestBridge
	local bridge = game:GetService("ServerStorage")[require(Shared.Types).Names.TestBridge]
	plot = PlotService.getPlot(userId)
	local target = standAt(20, 5)
	local res = bridge:Invoke("inventory.place", userId, pocketUid, target.X, target.Y, target.Z)
	T.check("hook inventory.place", res.ok == true and res.result.ok == true, res.error)
	res = bridge:Invoke("inventory.pocket", userId, pocketUid)
	T.check("hook inventory.pocket", res.ok == true and res.result.ok == true, res.error)

	DataService.getByUserId(userId).penLevel = 1 -- kembalikan nilai uji
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
