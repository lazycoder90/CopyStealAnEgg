--!nonstrict
-- Skenario uji Fase 2 (Progresi): speed/WalkSpeed, Slow Mode, Sprint Wheel, upgrade Pen, slot equip,
-- ekspansi plot, Trail, dan AntiExploit.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Progression")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Formulas = require(Shared.Logic.Formulas)
local Progression = require(Shared.Config.Progression)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Clock = require(Server.Systems.Clock)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local AntiExploit = require(Server.Services.AntiExploit)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local PetService = require(Server.Services.PetService)
local PlotService = require(Server.Services.PlotService)
local SpeedService = require(Server.Services.SpeedService)
local TrailService = require(Server.Services.TrailService)
local UpgradeService = require(Server.Services.UpgradeService)
local WheelService = require(Server.Services.WheelService)

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge

	local function call(name, ...)
		local result = bridge:Invoke(name, ...)
		if result.ok then
			return true, result.result
		end
		return false, result.error
	end
	local function setCash(v: number)
		CurrencyService.set(userId, "cash", v)
	end
	local function humanoid()
		return Actors.getHumanoid(userId)
	end

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	T.check("pemain punya Coop", plot ~= nil)

	-- ===== Speed / WalkSpeed =====
	for _, value in { 10, 1e3, 170e3, 7e9 } do
		CurrencyService.set(userId, "speedBase", value)
		SpeedService.refresh(userId)
		T.check(
			`WalkSpeed cocok Formulas untuk speedBase {value}`,
			near(humanoid().WalkSpeed, Formulas.walkSpeed(value), 0.01),
			humanoid().WalkSpeed
		)
	end
	T.check(
		"getEffectiveSpeed = speedBase tanpa trail",
		SpeedService.getEffectiveSpeed(userId) == 7e9
	)

	SpeedService.setSlowMode(userId, true)
	T.check("Slow Mode membatasi WalkSpeed 20", humanoid().WalkSpeed == 20, humanoid().WalkSpeed)
	T.check("settings.slowMode tersimpan", data.settings.slowMode == true)
	SpeedService.setSlowMode(userId, false)
	T.check("Slow Mode mati memulihkan", near(humanoid().WalkSpeed, Formulas.walkSpeed(7e9), 0.01))

	CurrencyService.set(userId, "speedBase", 1000)
	data.boosts.speed2xUntil = Clock.now() + 100
	T.check(
		"potion speed memberi x1.5",
		near(SpeedService.getEffectiveSpeed(userId), 1500, 0.001),
		SpeedService.getEffectiveSpeed(userId)
	)
	data.boosts.speed2xUntil = 0

	-- Perubahan speedBase tanpa refresh eksplisit tetap diterapkan oleh loop 2 Hz.
	CurrencyService.set(userId, "speedBase", 50e3)
	T.wait(0.8)
	T.check(
		"loop 2 Hz menerapkan perubahan speedBase",
		near(humanoid().WalkSpeed, Formulas.walkSpeed(50e3), 0.01),
		humanoid().WalkSpeed
	)

	-- ===== Sprint Wheel =====
	CurrencyService.set(userId, "speedBase", 10)
	SpeedService.refresh(userId)
	local okInfo, info = call("wheel.info", userId)
	T.check("roda ada di plot", okInfo and info ~= nil)
	T.check("model roda bernama PlotWheel", plot:FindFirstChild(Types.Names.PlotWheel) ~= nil)
	T.check(
		"atribut WheelGain level 1",
		info and info.gain == Formulas.wheelGainPerStep(1),
		info and info.gain
	)

	local root = Actors.getRoot(userId)
	local center = Vector3.new(info.center[1], info.center[2], info.center[3])
	AntiExploit.grace(userId, 3, "test")
	root.CFrame = CFrame.new(center + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	T.wait(0.15)
	local before = data.speedBase
	local _, gainMoving = call("wheel.tick", userId, true)
	T.check(
		"tick berlari di roda memberi speed",
		gainMoving == Formulas.wheelGainPerStep(1),
		gainMoving
	)
	T.check("speedBase naik sesuai gain", data.speedBase == before + gainMoving)
	local _, gainStill = call("wheel.tick", userId, false)
	T.check("tick diam tidak memberi speed", gainStill == 0, gainStill)

	root.CFrame = CFrame.new(PlotService.localToWorld(plot, 0, 10) + Vector3.new(0, 4, 0))
	T.wait(0.15)
	local _, gainOff = call("wheel.tick", userId, true)
	T.check("tick di luar roda tidak memberi speed", gainOff == 0, gainOff)

	-- Upgrade roda
	setCash(0)
	local ok1, err1 = WheelService.upgrade(userId, "cash")
	T.check("upgrade roda tanpa uang ditolak", ok1 == false and data.wheelLevel == 1, err1)
	setCash(Formulas.wheelUpgradePrice(1) - 1)
	T.check("kurang 1 tetap ditolak", WheelService.upgrade(userId, "cash") == false)
	setCash(Formulas.wheelUpgradePrice(1))
	local ok2 = WheelService.upgrade(userId, "cash")
	T.check("upgrade roda berhasil", ok2 == true and data.wheelLevel == 2)
	T.check("uang terpotong tepat", data.cash == 0, data.cash)
	local wheelModel = plot:FindFirstChild(Types.Names.PlotWheel)
	T.check(
		"atribut roda diperbarui",
		wheelModel:GetAttribute(Types.Attr.WheelLevel) == 2
			and wheelModel:GetAttribute(Types.Attr.WheelGain) == Formulas.wheelGainPerStep(2)
	)
	local okR, errR = WheelService.upgrade(userId, "robux")
	T.check("jalur Robux memberi pesan ramah", okR == false and errR ~= nil, errR)
	data.wheelLevel = Progression.wheel.maxLevel
	setCash(1e300)
	T.check("level maksimum ditolak", WheelService.upgrade(userId, "cash") == false)
	data.wheelLevel = 1
	WheelService.refresh(userId)

	-- ===== Slot equip =====
	setCash(Progression.equipSlotPrices[4] - 1)
	T.check("slot equip uang kurang ditolak", UpgradeService.buyEquipSlot(userId) == false)
	setCash(Progression.equipSlotPrices[4])
	T.check(
		"slot equip dibeli",
		UpgradeService.buyEquipSlot(userId) == true and data.equipSlots == 4
	)
	T.check("slot equip memotong uang", data.cash == 0, data.cash)
	data.equipSlots = Progression.maxEquipSlots
	setCash(1e300)
	T.check("slot equip maksimum ditolak", UpgradeService.buyEquipSlot(userId) == false)
	data.equipSlots = Progression.startEquipSlots

	-- ===== Ekspansi plot =====
	setCash(Progression.plotExpansion.price - 1)
	T.check("ekspansi uang kurang ditolak", UpgradeService.buyPlotExpansion(userId) == false)
	setCash(Progression.plotExpansion.price + 5)
	T.check(
		"ekspansi berhasil",
		UpgradeService.buyPlotExpansion(userId) == true and data.plotExpansion == 1
	)
	T.check("ekspansi memotong harga", data.cash == 5, data.cash)
	T.check(
		"ekspansi hanya sekali",
		UpgradeService.buyPlotExpansion(userId) == false and data.cash == 5
	)
	T.check("slot telur bertambah", Progression.eggSlotsFor(data.penLevel, data.plotExpansion) == 5)

	-- ===== Upgrade Pen =====
	data.equipSlots = 6
	for _ = 1, 5 do
		local _, uid = call("pets.give", userId, Creatures.list[1].id, 1)
		PetService.equip(userId, uid)
	end
	local petsFolder = plot[Types.Names.PlotPets]
	T.check(
		"pen L1: 3 pet terlihat",
		#petsFolder:GetChildren() == Progression.visiblePetsFor(1),
		#petsFolder:GetChildren()
	)
	setCash(Progression.pen[2].price - 1)
	T.check(
		"pen uang kurang ditolak",
		UpgradeService.upgradePen(userId) == false and data.penLevel == 1
	)
	setCash(Progression.pen[2].price)
	T.check("pen L2 berhasil", UpgradeService.upgradePen(userId) == true and data.penLevel == 2)
	T.check("pen memotong harga", data.cash == 0, data.cash)
	T.check("atribut PenLevel plot", plot:GetAttribute(Types.Attr.PenLevel) == 2)
	T.check(
		"pen L2: 4 pet terlihat",
		#petsFolder:GetChildren() == Progression.visiblePetsFor(2),
		#petsFolder:GetChildren()
	)
	T.check(
		"papan pen dan ekspansi ada",
		plot:FindFirstChild(Types.Names.PlotPenSign) ~= nil
			and plot:FindFirstChild(Types.Names.PlotExpansionSign) ~= nil
	)
	data.penLevel = Progression.maxPenLevel
	setCash(1e300)
	T.check("pen maksimum ditolak", UpgradeService.upgradePen(userId) == false)
	data.penLevel = 2
	for uid in data.pets do
		PetService.unequip(userId, uid)
	end
	data.equipSlots = Progression.startEquipSlots

	-- ===== Trail =====
	local dust = Progression.trails[1]
	CurrencyService.set(userId, "speedBase", 1000)
	setCash(dust.cashPrice - 1)
	T.check("trail uang kurang ditolak", TrailService.buy(userId, dust.id, "cash") == false)
	T.check(
		"trail belum dimiliki tidak bisa dipasang",
		TrailService.equip(userId, dust.id) == false
	)
	setCash(dust.cashPrice)
	T.check(
		"trail dibeli",
		TrailService.buy(userId, dust.id, "cash") == true and data.trails.owned[dust.id] == true
	)
	T.check("trail ganda ditolak", TrailService.buy(userId, dust.id, "cash") == false)
	local okRb, errRb = TrailService.buy(userId, Progression.trails[4].id, "robux")
	T.check("trail Robux memberi pesan ramah", okRb == false and errRb ~= nil, errRb)
	T.check("trail tak dikenal ditolak", TrailService.buy(userId, "nope", "cash") == false)
	T.check(
		"trail dipasang",
		TrailService.equip(userId, dust.id) == true and data.trails.equipped == dust.id
	)
	T.check(
		"pengali trail masuk effectiveSpeed",
		near(SpeedService.getEffectiveSpeed(userId), 1000 * dust.mult, 0.001),
		SpeedService.getEffectiveSpeed(userId)
	)
	T.check(
		"WalkSpeed memakai speed efektif",
		near(humanoid().WalkSpeed, Formulas.walkSpeed(1000 * dust.mult), 0.01),
		humanoid().WalkSpeed
	)
	T.check("efek Trail ada di HRP", select(2, call("trail.hasVisual", userId)) == true)
	T.check(
		"trail dilepas (toggle)",
		TrailService.equip(userId, dust.id) == true and data.trails.equipped == false
	)
	T.check("efek Trail hilang", select(2, call("trail.hasVisual", userId)) == false)
	T.check("pengali kembali 1", near(SpeedService.getEffectiveSpeed(userId), 1000, 0.001))

	-- ===== AntiExploit =====
	T.check("travelPlausible dekat sah", AntiExploit.travelPlausible(userId, 10, 0) == true)
	T.check("travelPlausible jauh tidak sah", AntiExploit.travelPlausible(userId, 1000, 1) == false)

	CurrencyService.set(userId, "speedBase", 10)
	SpeedService.refresh(userId)
	local base = PlotService.localToWorld(plot, 0, 0) + Vector3.new(0, 4, 0)
	require(Server.Systems.TestBridge).teleport(userId, base) -- grace 2.5 detik
	T.wait(3.2) -- grace habis; sampel sah terakhir = base
	root = Actors.getRoot(userId)
	local _, stats0 = call("antiexploit.stats", userId)
	root.CFrame = CFrame.new(base + Vector3.new(300, 0, 0))
	T.wait(1.1)
	local flat = Vector3.new(root.Position.X - base.X, 0, root.Position.Z - base.Z).Magnitude
	local _, stats1 = call("antiexploit.stats", userId)
	T.check("teleport 300 stud tanpa grace dikembalikan", flat < 30, flat)
	T.check("pelanggaran tercatat", stats1.violations > stats0.violations, stats1.violations)

	AntiExploit.grace(userId, 1.5, "test")
	root.CFrame = CFrame.new(base + Vector3.new(300, 0, 0))
	T.wait(0.7)
	local flat2 = Vector3.new(root.Position.X - base.X, 0, root.Position.Z - base.Z).Magnitude
	T.check("teleport dengan grace tidak dikembalikan", flat2 > 250, flat2)
	local _, stats2 = call("antiexploit.stats", userId)
	T.check("grace tidak menambah pelanggaran", stats2.violations == stats1.violations)

	call("plot.teleport", userId)
	T.wait(2.2)

	-- ===== Invarian =====
	data.penLevel = 1
	data.plotExpansion = 0
	UpgradeService.refresh(userId)
	local inv = InvariantChecker.check()
	T.check("invarian bersih di akhir", #inv == 0, table.concat(inv, " | "))
end
