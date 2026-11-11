--!nonstrict
-- Skenario uji tutorial: alur penuh langkah 1..8 dengan service nyata, bonus $1000 sekali, skip,
-- proteksi newbie, tidak macet. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Tutorial")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Logic.Formulas)
local Layout = require(Shared.Config.Layout)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Clock = require(Server.Systems.Clock)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local CarryService = require(Server.Services.CarryService)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)
local HatchService = require(Server.Services.HatchService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)
local TutorialService = require(Server.Services.TutorialService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage:FindFirstChild(Types.Names.TestBridge)

	local function teleport(pos: Vector3)
		require(Server.Systems.TestBridge).teleport(userId, pos + Vector3.new(0, 4, 0))
		T.wait(0.15)
	end
	local function waitFor(cond, timeout: number)
		local start = os.clock()
		while os.clock() - start < timeout do
			if cond() then
				return true
			end
			T.wait(0.1)
		end
		return cond()
	end
	local function step()
		local tutorial = DataService.getByUserId(userId).tutorial
		return tutorial.step
	end
	local function grabNearest(zone)
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
			return false, "tidak ada telur"
		end
		teleport(EggSpawnService.entityPosition(best) + Vector3.new(4, 0, 0))
		return CarryService.tryPickupWorld(userId, best.uid)
	end
	local function fresh()
		DataService.wipe(userId)
		T.wait(1.5)
		return DataService.getByUserId(userId)
	end

	-- ===== Profil baru =====
	local data = fresh()
	T.check("langkah awal 1", data.tutorial.step == 1 and data.tutorial.done == false)
	T.check("isActive true", TutorialService.isActive(userId))
	local protect = data.newbieProtectUntil - Clock.now()
	T.check("newbieProtectUntil ~300 detik", protect > 280 and protect <= 301, protect)

	-- ===== Alur penuh =====
	local ok, err = grabNearest(1)
	T.check("grab telur", ok == true, err)
	T.check(
		"langkah 2 setelah grab",
		waitFor(function()
			return step() == 2
		end, 1.5),
		step()
	)
	T.wait(0.6)
	T.check("langkah 2 bertahan sebelum lewat Hearth Line", step() == 2)
	teleport(Vector3.new(0, 4, Layout.hearthLineZ - 12))
	T.check(
		"langkah 3 setelah lewat Hearth Line",
		waitFor(function()
			return step() == 3
		end, 1.5),
		step()
	)
	local plot = PlotService.getPlot(userId)
	teleport(PlotService.localToWorld(plot, 0, 0))
	local okP, errP = PlacementService.place(userId, PlotService.localToWorld(plot, 0, -5))
	T.check("place berhasil", okP == true, errP)
	T.check(
		"langkah 4 setelah place",
		waitFor(function()
			return step() == 4
		end, 1.5),
		step()
	)

	local eggUid
	for uid in data.eggs do
		eggUid = uid
	end
	bridge:Invoke("growth.advance", userId, eggUid, 100000)
	local okH, payload = HatchService.hatch(userId, eggUid)
	T.check("hatch berhasil", okH == true, payload)
	T.check(
		"langkah 5 setelah hatch",
		waitFor(function()
			return step() == 5
		end, 1.5),
		step()
	)
	local cashAtFive = data.cash
	T.wait(2)
	T.check("langkah 5 belum maju sebelum 4 detik", step() == 5)
	T.check(
		"langkah 6 otomatis setelah ~4 detik",
		waitFor(function()
			return step() == 6
		end, 4),
		step()
	)
	T.check("bonus $1000 diberikan", data.cash >= cashAtFive + 1000, data.cash - cashAtFive)
	T.check("bendera bonus tersimpan", data.tutorial.bonus == true)
	local cashAtSix = data.cash
	T.wait(2)
	T.check("bonus tidak berulang", data.cash - cashAtSix < 900, data.cash - cashAtSix)
	T.check("langkah 6 menunggu upgrade Coop", step() == 6)

	data.plotExpansion = 1
	T.check(
		"langkah 7 setelah expansion",
		waitFor(function()
			return step() == 7
		end, 1.5),
		step()
	)
	T.check("baseline speed tercatat", data.tutorial.baseline == data.speedBase)
	local needed = 30 * Formulas.wheelGainPerStep(data.wheelLevel)
	CurrencyService.set(userId, "speedBase", data.tutorial.baseline + needed - 1)
	T.wait(0.8)
	T.check("langkah 7 belum selesai (kurang 1)", step() == 7)
	CurrencyService.set(userId, "speedBase", data.tutorial.baseline + needed)
	T.check(
		"selesai (done) setelah 30 step",
		waitFor(function()
			return DataService.getByUserId(userId).tutorial.done == true
		end, 1.5)
	)
	T.check("langkah 8", step() == 8)
	T.check("isActive false", not TutorialService.isActive(userId))

	-- ===== Skip =====
	data = fresh()
	T.check("profil baru kembali ke langkah 1", step() == 1 and not data.tutorial.done)
	TutorialService.skip(userId)
	T.check("skip: done dan langkah 8", data.tutorial.done == true and step() == 8)
	T.check("skip: isActive false", not TutorialService.isActive(userId))

	-- ===== Tidak macet: telur hilang saat langkah 2 =====
	data = fresh()
	local okG = grabNearest(1)
	T.check("grab (deadlock)", okG == true)
	waitFor(function()
		return step() == 2
	end, 1.5)
	CarryService.forceReturn(userId, "caught")
	T.check(
		"langkah 2 kembali ke 1 jika telur hilang",
		waitFor(function()
			return step() == 1
		end, 1.5),
		step()
	)
	-- Langkah 3 + telur dijatuhkan
	grabNearest(1)
	teleport(Vector3.new(0, 4, Layout.hearthLineZ - 12))
	waitFor(function()
		return step() == 3
	end, 1.5)
	CarryService.drop(userId, "dropped")
	T.check(
		"langkah 3 kembali ke 1 jika telur dijatuhkan",
		waitFor(function()
			return step() == 1
		end, 1.5),
		step()
	)

	-- ===== Admin/hook: loncat langkah =====
	bridge:Invoke("tutorial.set", userId, 5)
	T.check("loncat ke langkah 5", step() == 5)
	T.check(
		"langkah 5 -> 6 otomatis",
		waitFor(function()
			return step() == 6
		end, 5)
	)

	-- ===== Pemain lama (sudah pernah hatch) langsung done =====
	data = fresh()
	data.stats.hatched = 1
	data.newbieProtectUntil = 0 -- fresh() = profil baru yang sudah dapat proteksi; simulasikan pemain lama
	local rejoined = DataService.simulateRejoin(userId)
	T.wait(1.5)
	T.check("simulateRejoin berhasil", rejoined == true)
	data = DataService.getByUserId(userId)
	T.check(
		"stats.hatched > 0 saat join -> done",
		data.tutorial.done == true and data.tutorial.step == 8
	)
	T.check("pemain lama tidak dapat proteksi newbie baru", data.newbieProtectUntil == 0)

	-- ===== Akhir =====
	fresh()
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
