--!nonstrict
-- Uji perbaikan hasil review kode: grace roda terbatas, stun tak bisa dibatalkan, imunitas tutorial
-- dibatasi waktu, pencuri kehilangan proteksi, kebal-pickup berlaku di recover, hitungan "curi" sekali,
-- percepatan tutorial hanya telur pertama, skip tutorial melepas proteksi, provider income aman.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Hardening")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Bots = require(Server.Systems.Bots)
local Clock = require(Server.Systems.Clock)
local GameEvents = require(Server.Systems.GameEvents)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local TestBridge = require(Server.Systems.TestBridge)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local GrowthService = require(Server.Services.GrowthService)
local IncomeService = require(Server.Services.IncomeService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)
local SpeedService = require(Server.Services.SpeedService)
local StealService = require(Server.Services.StealService)
local TutorialService = require(Server.Services.TutorialService)

local Names, Attr = Types.Names, Types.Attr

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage:FindFirstChild(Names.TestBridge)
	local VICTIM = -1

	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		if r.ok then
			return r.result
		end
		return nil
	end
	local function tp(pos: Vector3)
		TestBridge.teleport(userId, pos)
		T.wait(0.15)
	end
	local function fresh()
		Bots.removeAll()
		DataService.wipe(userId)
		T.wait(1.5)
		return DataService.getByUserId(userId)
	end
	local function data()
		return DataService.getByUserId(userId)
	end

	-- ===== 1. Grace roda tidak boleh dipakai untuk teleport jauh =====
	fresh()
	data().tutorial.done = true
	data().newbieProtectUntil = 0
	local plot = PlotService.getPlot(userId)
	local platform = plot[Names.PlotWheel].PrimaryPart
	tp(platform.Position + Vector3.new(0, 4, 0))
	T.wait(3.2) -- grace teleport uji habis; sampel sah terakhir = di roda
	local root = Actors.getRoot(userId)
	local base = root.Position
	call("wheel.tick", userId, true) -- memberi grace roda (0.6 detik)
	root.CFrame = CFrame.new(base + Vector3.new(300, 0, 0))
	T.wait(1.1)
	local flat = Vector3.new(root.Position.X - base.X, 0, root.Position.Z - base.Z).Magnitude
	T.check("teleport 300 stud saat grace roda tetap dikembalikan", flat < 120, flat)
	call("plot.teleport", userId)
	T.wait(2.5)

	-- ===== 2. Stun tidak boleh ditimpa SpeedService =====
	local humanoid = Actors.getHumanoid(userId)
	humanoid:SetAttribute(Attr.Stunned, true)
	humanoid.WalkSpeed = 0
	SpeedService.refresh(userId)
	T.wait(0.1)
	T.check("refresh tidak membatalkan stun", humanoid.WalkSpeed == 0, humanoid.WalkSpeed)
	call("speed.setSlow", userId, true)
	T.check("slow mode tidak membatalkan stun", humanoid.WalkSpeed == 0, humanoid.WalkSpeed)
	call("speed.setSlow", userId, false)
	humanoid:SetAttribute(Attr.Stunned, nil)
	SpeedService.refresh(userId)
	T.check(
		"WalkSpeed pulih setelah stun",
		math.abs(humanoid.WalkSpeed - SpeedService.getWalkSpeed(userId)) < 1e-6
			and humanoid.WalkSpeed > 0,
		humanoid.WalkSpeed
	)

	-- ===== 3. Imunitas tutorial guardian dibatasi jendela newbie =====
	data().tutorial.done = false
	data().newbieProtectUntil = Clock.now() + 300
	call("guardian.sleep", 1)
	local egg = call("eggs.nearest", userId, 1)
	tp(Vector3.new(egg.pos[1] + 4, egg.pos[2] + 3, egg.pos[3]))
	local pick = call("carry.pickup", userId, egg.uid)
	T.check("grab (jendela newbie aktif)", pick and pick.ok == true, pick and pick.err)
	T.wait(2)
	T.check(
		"guardian tetap tidur saat jendela newbie aktif",
		call("guardian.state", 1) == "Sleep",
		call("guardian.state", 1)
	)
	CarryService.forceReturn(userId, "returned")
	T.wait(2.2) -- kebal pickup

	data().newbieProtectUntil = 0
	call("guardian.sleep", 1)
	egg = call("eggs.nearest", userId, 1)
	tp(Vector3.new(egg.pos[1] + 4, egg.pos[2] + 3, egg.pos[3]))
	pick = call("carry.pickup", userId, egg.uid)
	T.check("grab (jendela newbie habis)", pick and pick.ok == true, pick and pick.err)
	T.wait(1.5)
	T.check(
		"guardian bangun setelah jendela newbie habis",
		call("guardian.state", 1) ~= "Sleep",
		call("guardian.state", 1)
	)
	CarryService.forceReturn(userId, "returned")
	call("guardian.sleep", 1)
	T.wait(2.2)

	-- ===== 4. Steal: korban dilindungi hanya oleh jendela newbie; pencuri kehilangan proteksinya =====
	data().tutorial.done = true
	Bots.spawn(VICTIM)
	local bdata = DataService.getByUserId(VICTIM)
	bdata.tutorial.done = false -- bukan lagi alasan proteksi
	bdata.newbieProtectUntil = 0
	local eggUid = Bots.giveEgg(VICTIM, "moss_pup", nil, true)
	T.wait(0.3)
	local model = GrowthService.getModel(VICTIM, eggUid)
	tp(model:GetPivot().Position + Vector3.new(4, 3, 0))
	data().newbieProtectUntil = Clock.now() + 300
	local ok, err = StealService.trySteal(userId, VICTIM, eggUid)
	T.check("korban tanpa jendela newbie bisa dicuri walau tutorial belum selesai", ok == true, err)
	T.check(
		"pencuri kehilangan proteksi newbie",
		(data().newbieProtectUntil or 0) == 0,
		data().newbieProtectUntil
	)

	-- kebal pickup berlaku pada recover (bukan hanya pickup telur dunia)
	CarryService.drop(userId, "dropped")
	T.wait(0.2)
	CarryService.setPickupImmunity(userId, 3)
	local okRec, errRec = StealService.recover(userId, VICTIM, eggUid)
	T.check("recover ditolak saat kebal pickup", okRec == false, errRec)
	CarryService.setPickupImmunity(userId, 0)
	-- ambil lagi, taruh di Coop sendiri
	local okAgain = StealService.recover(userId, VICTIM, eggUid, true)
	T.check("recover paksa berhasil", okAgain == true)

	-- ===== 5. "Dicuri" dihitung sekali walau telur dikantongi lalu ditaruh ulang =====
	local stolenEvents = 0
	local conn = GameEvents.EggPlaced:Connect(function(payload)
		if payload.userId == userId and payload.stolen == true then
			stolenEvents += 1
		end
	end)
	local floor = PlotService.getFloor(plot)
	tp(floor.Position + Vector3.new(0, 4, 0))
	local placeOk, placeErr = PlacementService.place(userId, PlotService.localToWorld(plot, 0, -8))
	T.check("menaruh telur curian", placeOk == true, placeErr)
	T.wait(0.2)
	local stolenUid
	for uid, e in data().eggs do
		if e.stolenFrom ~= nil then
			stolenUid = uid
		end
	end
	T.check("telur curian ada di profil pencuri", stolenUid ~= nil)
	T.check("stolenCounted tercatat", stolenUid and data().eggs[stolenUid].stolenCounted == true)
	T.check("1 event curian setelah penempatan pertama", stolenEvents == 1, stolenEvents)
	for _ = 1, 3 do
		call("inventory.pocket", userId, stolenUid)
		call("inventory.place", userId, stolenUid, floor.Position.X, 0.5, floor.Position.Z - 8)
		T.wait(0.2)
		for uid, e in data().eggs do
			if e.stolenFrom ~= nil then
				stolenUid = uid
			end
		end
	end
	conn:Disconnect()
	T.check("pocket + place ulang tidak menghitung curian lagi", stolenEvents == 1, stolenEvents)
	Bots.removeAll()

	-- ===== 6. Percepatan tutorial hanya untuk telur PERTAMA dengan rarity rendah =====
	fresh()
	local d = data()
	d.tutorial.done = false
	d.stats.hatched = 0
	PlacementService.insert(
		userId,
		{ uid = "hdA", id = "bramble_fox", kg = 2, muts = {}, growTotal = 1000, progress = 0 },
		-20,
		-10
	)
	T.check(
		"telur pertama rarity tinggi tidak dipercepat",
		data().eggs.hdA.growTotal == 1000,
		data().eggs.hdA.growTotal
	)
	PlacementService.insert(
		userId,
		{ uid = "hdB", id = "moss_pup", kg = 2, muts = {}, growTotal = 1000, progress = 0 },
		20,
		-10
	)
	T.check(
		"telur kedua tidak dipercepat",
		data().eggs.hdB.growTotal == 1000,
		data().eggs.hdB.growTotal
	)
	fresh()
	d = data()
	d.tutorial.done = false
	d.stats.hatched = 0
	PlacementService.insert(
		userId,
		{ uid = "hdC", id = "moss_pup", kg = 2, muts = {}, growTotal = 1000, progress = 0 },
		0,
		-10
	)
	T.check(
		"telur pertama rarity rendah dipercepat",
		data().eggs.hdC.growTotal <= Eggs.tutorialGrowSeconds,
		data().eggs.hdC.growTotal
	)

	-- ===== 7. Skip tutorial melepas proteksi newbie =====
	fresh()
	T.check("profil baru punya proteksi newbie", (data().newbieProtectUntil or 0) > Clock.now())
	TutorialService.skip(userId)
	T.check(
		"skip tutorial melepas proteksi",
		(data().newbieProtectUntil or 0) == 0,
		data().newbieProtectUntil
	)
	T.check("tutorial selesai setelah skip", data().tutorial.done == true)

	-- ===== 8. Provider income yang error tidak mematikan income =====
	local petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	local before = IncomeService.compute(userId, data())
	IncomeService.addBonus("hardening_bad", function()
		error("boom")
	end)
	local okCompute, after = pcall(IncomeService.compute, userId, data())
	T.check("compute tidak melempar error saat provider error", okCompute == true, after)
	T.check(
		"income tetap sama (provider error diabaikan)",
		okCompute and math.abs(after - before) < 1e-9,
		after
	)
	IncomeService.addBonus("hardening_bad", function()
		return 0
	end)

	-- ===== Pemulihan =====
	fresh()
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
