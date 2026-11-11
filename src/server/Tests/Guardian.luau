--!nonstrict
-- Skenario uji Nestwarden: 12 guardian tidur, tutorial mengabaikan guardian, Alert -> Chase -> Catch,
-- Return saat melewati Hearth Line, tidak pernah melewati Hearth Line, retarget dua pembawa, invarian.
-- Lambat (~1-2 menit). Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Guardian")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local GuardianConfig = require(Shared.Config.GuardianConfig)
local Layout = require(Shared.Config.Layout)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)

local BOT_ID = -9001

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
	local function state(zone)
		return call("guardian.state", zone)
	end
	local function info(zone)
		return call("guardian.info", zone)
	end
	local function teleport(id, pos: Vector3)
		require(Server.Systems.TestBridge).teleport(id, pos + Vector3.new(0, 4, 0))
		T.wait(0.15)
	end
	-- Menunggu sampai kondisi benar atau habis waktu (detik nyata).
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
	-- Telur Occupied zona 1, diurutkan menurut Z.
	local function zoneEggs(zone)
		local list = {}
		for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
			local uid = model:GetAttribute(Types.Attr.EggUid)
			local entity = uid and EggSpawnService.getEntity(uid)
			if
				entity
				and entity.state == "Occupied"
				and entity.zone == zone
				and not entity.grand
			then
				table.insert(list, entity)
			end
		end
		table.sort(list, function(a, b)
			return EggSpawnService.entityPosition(a).Z < EggSpawnService.entityPosition(b).Z
		end)
		return list
	end
	local function grab(id, entity)
		teleport(id, EggSpawnService.entityPosition(entity) + Vector3.new(4, 0, 0))
		return CarryService.tryPickupWorld(id, entity.uid)
	end
	local function resetAll()
		for _, id in { userId, BOT_ID } do
			CarryService.forceReturn(id, "returned")
		end
		call("guardian.sleep", 1)
		T.wait(0.3)
	end

	DataService.wipe(userId)
	T.wait(1.5)
	local data = DataService.getByUserId(userId)

	-- ===== Dasar =====
	local guardianFolder = workspace[Types.Names.Guardians]
	T.check("12 guardian ada", #guardianFolder:GetChildren() == 12, #guardianFolder:GetChildren())
	local stats = call("guardian.stats")
	T.check("semua tidur di awal", stats and stats.Sleep == 12 and stats.total == 12)
	local model1 = guardianFolder:GetChildren()[1]
	T.check(
		"model guardian bertag dan beratribut",
		model1:HasTag(Types.Tags.Guardian)
			and model1:GetAttribute(Types.Attr.GuardianId) ~= nil
			and model1:GetAttribute(Types.Attr.GuardianState) == "Sleep"
			and model1:GetAttribute(Types.Attr.ZoneIndex) ~= nil
	)
	local home1x, home1z = GuardianConfig.home(1)
	local before = info(1)
	T.check(
		"guardian 1 di rumah",
		math.abs(before.x - home1x) < 0.01 and math.abs(before.z - home1z) < 0.01
	)
	local inv = InvariantChecker.check()
	T.check("invarian bersih di awal", #inv == 0, table.concat(inv, " | "))

	-- ===== Tutorial: guardian tidak bangun =====
	T.check("tutorial belum selesai", data.tutorial.done == false)
	local eggs = zoneEggs(1)
	T.check("ada telur zona 1", #eggs >= 4, #eggs)
	local ok1, err1 = grab(userId, eggs[#eggs])
	T.check("grab (tutorial)", ok1 == true, err1)
	T.wait(2.2)
	T.check("guardian tetap tidur saat tutorial", state(1) == "Sleep", state(1))
	CarryService.forceReturn(userId, "returned")
	T.wait(0.2)

	-- ===== Alert -> Chase -> Catch =====
	data = DataService.getByUserId(userId)
	data.tutorial.done = true
	data.tutorial.step = 8
	local statsBefore = data.stats.caught
	eggs = zoneEggs(1)
	local target = eggs[1] -- paling jauh dari rumah guardian (Z terkecil)
	local ok2, err2 = grab(userId, target)
	T.check("grab setelah tutorial", ok2 == true, err2)
	T.wait(0.3)
	T.check("guardian Alert", state(1) == "Alert", state(1))
	T.check(
		"atribut state tersinkron",
		guardianFolder:FindFirstChild("Grumblemoss")
			and guardianFolder.Grumblemoss:GetAttribute(Types.Attr.GuardianState) == "Alert"
	)
	T.check("belum mengejar sebelum wakeDelay", state(1) == "Alert")
	T.check(
		"Chase setelah wakeDelay",
		waitFor(function()
			return state(1) == "Chase"
		end, GuardianConfig.wakeDelay + 1)
	)

	local humanoid = Actors.getHumanoid(userId)
	local walkBefore = humanoid.WalkSpeed
	local minZ = math.huge
	local caught = waitFor(function()
		local i = info(1)
		if i then
			minZ = math.min(minZ, i.z)
		end
		return data.stats.caught > statsBefore
	end, 40)
	T.check("tertangkap (stats.caught naik)", caught and data.stats.caught == statsBefore + 1)
	T.check("tidak membawa lagi", not CarryService.isCarrying(userId))
	T.check("nest tidak Carried", EggSpawnService.stats().Carried == 0)
	T.check("guardian Return setelah menangkap", state(1) == "Return", state(1))
	T.check("WalkSpeed ditahan 0 saat pingsan", humanoid.WalkSpeed == 0, humanoid.WalkSpeed)
	T.check("telur target kembali ke sarang", target.state == "Occupied", target.state)

	local okImm, errImm = grab(userId, target)
	T.check("kebal pickup: grab ditolak", okImm == false, errImm)
	T.wait(1.8)
	T.check(
		"WalkSpeed dipulihkan",
		humanoid.WalkSpeed == walkBefore and humanoid.WalkSpeed > 0,
		humanoid.WalkSpeed
	)
	T.check("pemain tidak macet (bisa bergerak)", humanoid.WalkSpeed > 0)
	T.wait(0.8)
	local okAfter, errAfter = grab(userId, target)
	T.check("grab lagi setelah 2 detik", okAfter == true, errAfter)
	resetAll()
	T.check("tidak membawa setelah reset", not CarryService.isCarrying(userId))

	-- ===== Hearth Line: target menyeberang -> Return -> Sleep =====
	eggs = zoneEggs(1)
	local ok3, err3 = grab(userId, eggs[1])
	T.check("grab (hearth)", ok3 == true, err3)
	T.check(
		"Chase (hearth)",
		waitFor(function()
			return state(1) == "Chase"
		end, 3)
	)
	teleport(userId, Vector3.new(0, 4, Layout.hearthLineZ - 15))
	T.check(
		"Return setelah target melewati Hearth Line",
		waitFor(function()
			-- Jika guardian masih di rumah, Return selesai seketika dan langsung Sleep.
			local st = state(1)
			return st == "Return" or st == "Sleep"
		end, 1.5),
		state(1)
	)
	T.check(
		"kembali Sleep di rumah",
		waitFor(function()
			return state(1) == "Sleep"
		end, 30),
		state(1)
	)
	local after = info(1)
	T.check(
		"posisi kembali ke rumah",
		math.abs(after.z - home1z) < 0.01 and math.abs(after.x - home1x) < 0.01
	)
	resetAll()

	-- ===== Guardian tidak pernah melewati Hearth Line =====
	T.wait(2.2) -- tunggu kebal pickup habis
	eggs = zoneEggs(1)
	local ok4, err4 = grab(userId, eggs[1])
	T.check("grab (clamp)", ok4 == true, err4)
	teleport(userId, Vector3.new(0, 4, Layout.hearthLineZ + 6)) -- tepat di lane, dekat garis
	local minSeen = math.huge
	local caught2 = waitFor(function()
		local i = info(1)
		if i then
			minSeen = math.min(minSeen, i.z)
		end
		return data.stats.caught >= 2
	end, 40)
	T.check("tertangkap di dekat Hearth Line", caught2)
	T.check(
		"guardian tidak pernah di bawah Hearth Line + 3",
		minSeen >= Layout.hearthLineZ + 3,
		minSeen
	)
	T.check("min Z sebelumnya juga aman", minZ >= Layout.hearthLineZ + 3, minZ)
	resetAll()

	-- ===== Dua pembawa: pindah target ke yang lebih dekat =====
	T.wait(2.2)
	local botModel = Instance.new("Model")
	botModel.Name = "GuardianTestBot"
	local function botPart(name, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.Parent = botModel
		return p
	end
	local botRoot = botPart("HumanoidRootPart", Vector3.new(2, 2, 1))
	botPart("Head", Vector3.new(2, 1, 1))
	local botHumanoid = Instance.new("Humanoid")
	botHumanoid.WalkSpeed = 16
	botHumanoid.Parent = botModel
	botModel.PrimaryPart = botRoot
	botModel.Parent = workspace
	Actors.registerBot(BOT_ID, botModel)
	local botData = DataService.registerVirtual(BOT_ID, nil, botModel)
	botData.tutorial.done = true
	botData.tutorial.step = 8

	eggs = zoneEggs(1)
	local far, near = eggs[1], eggs[#eggs]
	local farZ = EggSpawnService.entityPosition(far).Z
	local nearZ = EggSpawnService.entityPosition(near).Z
	T.check("dua telur berjarak cukup", nearZ - farZ > 30, nearZ - farZ)
	local okA = grab(userId, far)
	T.check("pemain grab telur jauh", okA == true)
	T.check(
		"Chase pemain",
		waitFor(function()
			return state(1) == "Chase"
		end, 3)
	)
	T.check("target awal = pemain", info(1).target == userId)
	local pos = EggSpawnService.entityPosition(near) + Vector3.new(4, 0, 0)
	botRoot.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	local okB, errB = CarryService.tryPickupWorld(BOT_ID, near.uid)
	T.check("bot grab telur dekat", okB == true, errB)
	T.wait(0.3)
	T.check("guardian pindah ke pembawa lebih dekat", info(1).target == BOT_ID, info(1).target)
	T.check("guardian tetap Chase", state(1) == "Chase", state(1))

	-- Bot keluar: guardian tidak mengejar target yang hilang.
	DataService.unregisterVirtual(BOT_ID)
	Actors.unregisterBot(BOT_ID)
	botModel:Destroy()
	T.wait(0.3)
	T.check("telur bot kembali ke sarang", near.state == "Occupied", near.state)
	T.check("target bot dilepas", info(1).target ~= BOT_ID)
	CarryService.forceReturn(userId, "returned")
	call("guardian.sleep", 1)
	T.wait(0.3)

	-- ===== Akhir =====
	local final = call("guardian.stats")
	T.check("semua tidur di akhir", final and final.Sleep == 12)
	T.check("tidak ada telur Carried", EggSpawnService.stats().Carried == 0)
	local inv2 = InvariantChecker.check()
	T.check("invarian bersih di akhir", #inv2 == 0, table.concat(inv2, " | "))
end
