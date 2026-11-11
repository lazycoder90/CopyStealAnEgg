--!nonstrict
-- Skenario uji PvP: mencuri telur (bot sebagai korban). Lambat (~50 detik).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Steal")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Bots = require(Server.Systems.Bots)
local Clock = require(Server.Systems.Clock)
local GameEvents = require(Server.Systems.GameEvents)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local AntiExploit = require(Server.Services.AntiExploit)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local DefenseService = require(Server.Services.DefenseService)
local GrowthService = require(Server.Services.GrowthService)
local HatchService = require(Server.Services.HatchService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)
local StealService = require(Server.Services.StealService)

local Names, Attr = Types.Names, Types.Attr

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local VICTIM = -1
	local HELPER = -2
	local SPECIES = "moss_pup"

	local function teleport(pos: Vector3)
		AntiExploit.grace(userId, 5, "test")
		local root = Actors.getRoot(userId)
		root.CFrame = CFrame.new(pos)
		root.AssemblyLinearVelocity = Vector3.zero
		T.wait(0.15)
	end
	local function nearEgg(victimId: number, uid: string)
		local model = GrowthService.getModel(victimId, uid)
		teleport(model:GetPivot().Position + Vector3.new(4, 3, 0))
	end
	local function prepPlayer()
		local data = DataService.getByUserId(userId)
		data.tutorial.done = true
		data.newbieProtectUntil = 0
		return data
	end
	local function prepBot(id: number)
		local data = DataService.getByUserId(id)
		data.tutorial.done = true
		data.newbieProtectUntil = 0
		return data
	end
	local function totalEggs(): number
		local n = 0
		for _, entry in DataService.all() do
			for _ in entry.data.eggs do
				n += 1
			end
		end
		return n
	end
	local function stolenModels(): number
		local n = 0
		local effects = workspace:FindFirstChild(Names.Effects)
		for _, child in effects and effects:GetChildren() or {} do
			if string.sub(child.Name, 1, 9) == "StolenEgg" then
				n += 1
			end
		end
		return n
	end

	Bots.removeAll()
	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = prepPlayer()

	Bots.spawn(VICTIM)
	local bdata = prepBot(VICTIM)
	local readyUid = Bots.giveEgg(VICTIM, SPECIES, nil, true)
	local growUid = Bots.giveEgg(VICTIM, SPECIES, nil, false)
	local victimPlot = PlotService.getPlot(VICTIM)
	T.check("bot punya Coop dan 2 telur", victimPlot ~= nil and readyUid ~= nil and growUid ~= nil)
	local eggModel = GrowthService.getModel(VICTIM, readyUid)
	T.check("model telur bot ada", eggModel ~= nil)
	T.wait(0.2)
	local prompt = eggModel and eggModel.PrimaryPart:FindFirstChild(Names.StealPrompt)
	T.check(
		"StealPrompt di model placed",
		prompt ~= nil and prompt.ActionText == "Steal" and prompt.HoldDuration == 1.0,
		prompt
	)
	local eggsAtStart = totalEggs()

	-- ===== Penolakan =====
	nearEgg(VICTIM, readyUid)
	T.check(
		"tidak bisa mencuri dari diri sendiri",
		StealService.trySteal(userId, userId, readyUid) == false
	)

	bdata.newbieProtectUntil = Clock.now() + 100
	T.check("korban newbie terlindungi", StealService.trySteal(userId, VICTIM, readyUid) == false)
	bdata.newbieProtectUntil = 0
	-- (Proteksi korban hanya lewat jendela newbie; imunitas tutorial tanpa batas dicabut: lihat tes Hardening.)

	data.tutorial.done = false
	T.check(
		"pencuri belum selesai tutorial diblokir",
		StealService.trySteal(userId, VICTIM, readyUid) == false
	)
	data.tutorial.done = true

	bdata.shieldReadyAt = 0
	local shieldOk = DefenseService.activateShield(VICTIM)
	T.check(
		"Shield korban aktif",
		shieldOk == true and (victimPlot:GetAttribute(Attr.ShieldUntil) or 0) > Clock.now()
	)
	T.check("Shield memblokir pencurian", StealService.trySteal(userId, VICTIM, readyUid) == false)
	DefenseService.endShield(VICTIM)
	T.check("Shield berakhir: atribut 0", victimPlot:GetAttribute(Attr.ShieldUntil) == 0)
	-- Shield juga mendorong pemain keluar; kembali ke dekat telur sebelum mencoba lagi.
	nearEgg(VICTIM, readyUid)

	teleport(PlotService.getPlot(userId)[Names.PlotSpawn].Position + Vector3.new(0, 3, 0))
	T.check(
		"terlalu jauh dari telur ditolak",
		StealService.trySteal(userId, VICTIM, readyUid) == false
	)
	nearEgg(VICTIM, readyUid)
	T.check(
		"telur tidak dikenal ditolak",
		StealService.trySteal(userId, VICTIM, "nonexistent") == false
	)
	T.check(
		"penolakan tidak mengubah apa pun",
		not CarryService.isCarrying(userId)
			and not GrowthService.isFrozen(VICTIM, readyUid)
			and GrowthService.getModel(VICTIM, readyUid) ~= nil
			and StealService.activeCount() == 0
	)

	-- ===== Pencurian sukses =====
	local stolenEvent
	local connection = GameEvents.EggStolen:Connect(function(e)
		stolenEvent = e
	end)
	nearEgg(VICTIM, readyUid)
	local progressBefore = bdata.eggs[readyUid].progress
	local ok, err = StealService.trySteal(userId, VICTIM, readyUid)
	T.check("steal berhasil", ok == true, err)
	connection.Disconnect()

	local state = CarryService.get(userId)
	T.check("carry kind steal", state ~= nil and state.kind == "steal")
	T.check(
		"event EggStolen",
		stolenEvent ~= nil
			and stolenEvent.thiefId == userId
			and stolenEvent.victimId == VICTIM
			and stolenEvent.eggUid == readyUid
			and stolenEvent.speciesId == SPECIES
	)
	T.check("model di Coop korban hilang", GrowthService.getModel(VICTIM, readyUid) == nil)
	T.check(
		"telur beku dan tetap di profil korban",
		GrowthService.isFrozen(VICTIM, readyUid) and bdata.eggs[readyUid] ~= nil
	)
	local carryModel = state and state.model
	T.check(
		"model carry menempel di karakter dan Carried",
		carryModel ~= nil
			and carryModel.Parent == Actors.getCharacter(userId)
			and carryModel:GetAttribute(Attr.Carried) == true
			and carryModel:GetAttribute(Attr.EggUid) == readyUid
	)
	T.check("tanda StealAlert di plot korban", victimPlot:GetAttribute(Attr.StealAlert) == true)
	T.check("beenStolen korban = 1", bdata.stats.beenStolen == 1, bdata.stats.beenStolen)
	T.check("korban tidak bisa hatch telur beku", HatchService.hatch(VICTIM, readyUid) == false)
	T.check("pencuri tidak bisa hatch telur itu", HatchService.hatch(userId, readyUid) == false)
	T.check(
		"tidak bisa mencuri lagi sambil membawa",
		StealService.trySteal(userId, VICTIM, growUid) == false
	)
	T.check("jumlah telur global tetap saat dicuri", totalEggs() == eggsAtStart)

	-- ===== Place di Coop sendiri (transfer atomik) =====
	local plot = PlotService.getPlot(userId)
	teleport(plot[Names.PlotSpawn].Position + Vector3.new(0, 3, 0))
	ok, err = PlacementService.place(userId, PlotService.localToWorld(plot, 10, 10))
	T.check("place telur curian berhasil", ok == true, err)
	data = DataService.getByUserId(userId)
	local newUid, newEgg
	for uid, egg in data.eggs do
		if egg.stolenFrom == VICTIM then
			newUid, newEgg = uid, egg
		end
	end
	T.check("pencuri memiliki telur dengan stolenFrom", newEgg ~= nil)
	T.check(
		"progres dan spesies terjaga",
		newEgg ~= nil
			and math.abs(newEgg.progress - progressBefore) < 1e-6
			and newEgg.id == SPECIES
			and newEgg.progress >= newEgg.growTotal
	)
	T.check("telur hilang dari profil korban", bdata.eggs[readyUid] == nil)
	T.check("tidak beku lagi", not GrowthService.isFrozen(VICTIM, readyUid))
	T.check(
		"model telur ada di Coop pencuri",
		newUid ~= nil and GrowthService.getModel(userId, newUid) ~= nil
	)
	T.check("tidak membawa lagi", not CarryService.isCarrying(userId))
	T.check("stats.stolen pencuri = 1", data.stats.stolen == 1, data.stats.stolen)
	T.check("beenStolen korban tetap 1", bdata.stats.beenStolen == 1)
	T.check("jumlah telur global tetap setelah transfer", totalEggs() == eggsAtStart, totalEggs())
	T.check("tidak ada record tersisa", StealService.activeCount() == 0)
	local hatched = newUid and HatchService.hatch(userId, newUid)
	T.check("telur curian yang siap bisa menetas di pencuri", hatched == true)

	-- ===== Jatuh lalu diambil pihak lain / korban =====
	Bots.spawn(HELPER)
	prepBot(HELPER)
	nearEgg(VICTIM, growUid)
	ok, err = StealService.trySteal(userId, VICTIM, growUid)
	T.check("steal telur kedua", ok == true, err)
	CarryService.drop(userId, "dropped")
	T.check("pencuri berhenti membawa setelah drop", not CarryService.isCarrying(userId))
	local rec = StealService.getRecord(VICTIM, growUid)
	T.check(
		"record dropped dengan model di dunia",
		rec ~= nil and rec.stage == "dropped" and rec.model ~= nil and rec.model.Parent ~= nil
	)
	local grab = rec and rec.model.PrimaryPart:FindFirstChild(Names.GrabPrompt)
	T.check("GrabPrompt aktif di telur jatuh", grab ~= nil and grab.Enabled == true)
	T.check(
		"tetap beku dan di profil korban saat jatuh",
		GrowthService.isFrozen(VICTIM, growUid) and bdata.eggs[growUid] ~= nil
	)

	local picked = StealService.recover(HELPER, VICTIM, growUid, true)
	local helperState = CarryService.get(HELPER)
	T.check(
		"pemain lain melanjutkan membawa (kind steal, korban sama)",
		picked == true
			and helperState ~= nil
			and helperState.kind == "steal"
			and helperState.victimId == VICTIM
	)
	CarryService.forceReturn(HELPER, "returned")
	T.check(
		"forceReturn mengembalikan telur ke korban",
		GrowthService.getModel(VICTIM, growUid) ~= nil
			and not GrowthService.isFrozen(VICTIM, growUid)
			and StealService.activeCount() == 0
			and stolenModels() == 0
	)

	nearEgg(VICTIM, growUid)
	StealService.trySteal(userId, VICTIM, growUid)
	CarryService.drop(userId, "dropped")
	local recovered = StealService.recover(VICTIM, VICTIM, growUid, true)
	T.check(
		"korban mengambil kembali: telur pulang ke Coop",
		recovered == true
			and GrowthService.getModel(VICTIM, growUid) ~= nil
			and not GrowthService.isFrozen(VICTIM, growUid)
			and stolenModels() == 0
			and StealService.activeCount() == 0
	)

	-- ===== Auto-return 20 detik (waktu nyata) =====
	nearEgg(VICTIM, growUid)
	StealService.trySteal(userId, VICTIM, growUid)
	CarryService.drop(userId, "dropped")
	T.check("telur curian jatuh menunggu", StealService.getRecord(VICTIM, growUid) ~= nil)
	T.wait(Eggs.stolenEggReturnTime + 2)
	T.check(
		"auto-return: model korban kembali, tidak beku",
		GrowthService.getModel(VICTIM, growUid) ~= nil
			and not GrowthService.isFrozen(VICTIM, growUid)
			and StealService.activeCount() == 0
			and stolenModels() == 0
	)
	T.check(
		"tanda StealAlert padam setelah 8 detik",
		victimPlot:GetAttribute(Attr.StealAlert) == false
	)

	-- ===== Korban keluar saat telurnya dibawa =====
	nearEgg(VICTIM, growUid)
	ok = StealService.trySteal(userId, VICTIM, growUid)
	T.check("steal sebelum korban keluar", ok == true and CarryService.isCarrying(userId))
	Bots.remove(VICTIM)
	T.check("pencuri tidak membawa setelah korban keluar", not CarryService.isCarrying(userId))
	T.check(
		"tidak ada record/model curian tersisa",
		StealService.activeCount() == 0 and stolenModels() == 0
	)
	T.check("telur tetap utuh di profil korban", bdata.eggs[growUid] ~= nil)
	local character = Actors.getCharacter(userId)
	local leftover = false
	for _, child in character:GetChildren() do
		if string.sub(child.Name, 1, 9) == "StolenEgg" then
			leftover = true
		end
	end
	T.check("tidak ada model telur di karakter pencuri", not leftover)

	-- ===== Pencuri keluar saat membawa (simulateRejoin) =====
	Bots.spawn(VICTIM)
	bdata = prepBot(VICTIM)
	local uid3 = Bots.giveEgg(VICTIM, SPECIES, nil, true)
	data = prepPlayer()
	nearEgg(VICTIM, uid3)
	ok = StealService.trySteal(userId, VICTIM, uid3)
	T.check("steal sebelum pencuri keluar", ok == true)
	T.check("simulateRejoin berhasil", DataService.simulateRejoin(userId) == true)
	T.wait(1.2)
	T.check(
		"pencuri keluar: telur kembali ke korban",
		GrowthService.getModel(VICTIM, uid3) ~= nil
			and not GrowthService.isFrozen(VICTIM, uid3)
			and bdata.eggs[uid3] ~= nil
			and StealService.activeCount() == 0
			and not CarryService.isCarrying(userId)
	)

	Bots.removeAll()
	T.wait(0.3)
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
