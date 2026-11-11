--!nonstrict
-- DefenseService: Frying Pan, Sticky Yolk Trap, Shell Shield (docs/PLAN.md §4.5).
-- Semua timer PvP memakai waktu NYATA (os.clock); hanya timestamp tersimpan/atribut plot (shieldReadyAt,
-- ShieldUntil) memakai Clock.now(). Spawn pad (Layout.spawnPad) bebas PvP.
-- Hook TestBridge: defense.swing(userId), defense.trap(userId, x, y, z), defense.shield(userId), defense.stats().

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local NumberFormat = require(Shared.Logic.NumberFormat)
local PvpRules = require(Shared.Logic.PvpRules)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AntiExploit = require(script.Parent.AntiExploit)
local CarryService = require(script.Parent.CarryService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags

local DefenseService = {}

local DOME_DIAMETER = Layout.plotSize * 1.5
local SHIELD_PUSH_MARGIN = 3

local panMaids = {} -- [userId] = Maid (koneksi respawn Pan)
local swingAt = {} -- [userId] = os.clock() ayunan terakhir
local stunned = {} -- [userId] = { humanoid, previous }
local traps = {} -- [ownerId] = { { part, ownerId, expireAt }, ... }
local trapped = {} -- [userId] = { root, wasAnchored, maid }
local shields = {} -- [ownerId] = { dome, plot, untilAt }
local lastPush = 0

local function effectsFolder(): Instance
	local folder = workspace:FindFirstChild(Names.Effects)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Names.Effects
		folder.Parent = workspace
	end
	return folder
end

local function inSpawnPad(pos: Vector3): boolean
	local pad = Layout.spawnPad
	return PvpRules.inCircle(pos.X, pos.Z, pad.x, pad.z, pad.radius)
end

local function alive(userId: number): (BasePart?, Humanoid?)
	local root = Actors.getRoot(userId)
	local humanoid = Actors.getHumanoid(userId)
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- ===== Frying Pan =====

local function buildPan(): Tool
	local tool = Instance.new("Tool")
	tool.Name = PvpRules.panToolName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Bonk egg carriers!"
	tool.GripPos = Vector3.new(0, 0, 1)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 2.4)
	handle.Color = Color3.fromRGB(86, 52, 28)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "PanHead"
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(0.35, 2.6, 2.6)
	head.Color = Color3.fromRGB(60, 60, 66)
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool

	local joint = Instance.new("Weld")
	joint.Part0 = handle
	joint.Part1 = head
	joint.C0 = CFrame.new(0, 0, -2.3) * CFrame.Angles(0, 0, math.rad(90))
	joint.Parent = handle
	return tool
end

local function removePans(container: Instance?)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == PvpRules.panToolName then
			child:Destroy()
		end
	end
end

-- Taruh satu Pan di Backpack (hapus duplikat dan salinan di StarterGear).
local function givePan(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack or player.Parent ~= Players then
		return
	end
	removePans(player:FindFirstChild("StarterGear"))
	removePans(backpack)
	removePans(player.Character)
	buildPan().Parent = backpack
end

-- ===== Bonk =====

local function restoreStun(userId: number, record)
	if stunned[userId] ~= record then
		return
	end
	stunned[userId] = nil
	local humanoid = record.humanoid
	if humanoid.Parent then
		humanoid:SetAttribute(Attr.Stunned, nil)
		if humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = record.previous
		end
		-- Hitung ulang kecepatan sah (speed/trail bisa berubah selama stun).
		local ok, SpeedService = pcall(require, script.Parent.SpeedService)
		if ok then
			SpeedService.refresh(userId)
		end
	end
end

local function stun(userId: number)
	local humanoid = Actors.getHumanoid(userId)
	if not humanoid or stunned[userId] then
		return
	end
	local record = { humanoid = humanoid, previous = humanoid.WalkSpeed }
	stunned[userId] = record
	humanoid:SetAttribute(Attr.Stunned, true)
	humanoid.WalkSpeed = 0
	task.delay(PvpRules.panStun, restoreStun, userId, record)
end

local function bonk(targetId: number, swingerId: number, swingerRoot: BasePart)
	local targetRoot = Actors.getRoot(targetId)
	local away = targetRoot.Position - swingerRoot.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude < 1e-3 then
		flat = swingerRoot.CFrame.LookVector
	end
	local knock = flat.Unit * PvpRules.panKnockForce + Vector3.new(0, PvpRules.panKnockUp, 0)

	AntiExploit.grace(targetId, 2, "bonk")
	CarryService.setPickupImmunity(targetId, PvpRules.panBonkImmunity)
	CarryService.drop(targetId, "bonked")

	local player = Actors.getPlayer(targetId)
	if player then
		Net.fire("Bonked", player, { knock = knock })
	end
	stun(targetId)

	local data = DataService.getByUserId(swingerId)
	if data then
		data.stats.bonks = (data.stats.bonks or 0) + 1
		StateReplicator.set(swingerId, "stats.bonks", data.stats.bonks)
	end
	CarryService.notify(swingerId, "CLANG!", "success")
	GameEvents.Bonked:Fire({ userId = targetId, byUserId = swingerId })
end

-- Ayunan Pan (dipakai remote dan TestBridge). Mengembalikan true + jumlah korban, atau false + alasan.
function DefenseService.swing(userId: number): (boolean, any)
	local now = os.clock()
	if not PvpRules.cooldownReady(swingAt[userId], now, PvpRules.panCooldown) then
		return false, "cooldown"
	end
	local root = alive(userId)
	if not root then
		return false, "dead"
	end
	swingAt[userId] = now
	if inSpawnPad(root.Position) then
		return false, "spawn pad"
	end

	local look = root.CFrame.LookVector
	local hits = 0
	for _, entry in DataService.all() do
		local targetId = entry.userId
		if targetId ~= userId and CarryService.isCarrying(targetId) then
			local targetRoot = alive(targetId)
			if targetRoot and not inSpawnPad(targetRoot.Position) then
				local delta = targetRoot.Position - root.Position
				if
					math.abs(delta.Y) <= PvpRules.panMaxHeightDiff
					and PvpRules.inSwingCone(
						delta.X,
						delta.Z,
						look.X,
						look.Z,
						PvpRules.panRange,
						PvpRules.panHalfAngle
					)
				then
					bonk(targetId, userId, root)
					hits += 1
				end
			end
		end
	end
	return true, hits
end

-- Uji: hapus cooldown ayunan supaya skenario tidak perlu menunggu 1.2 detik.
function DefenseService.resetSwingCooldown(userId: number)
	swingAt[userId] = nil
end

function DefenseService.isStunned(userId: number): boolean
	return stunned[userId] ~= nil
end

-- ===== Sticky Yolk Trap =====

local function releaseTrap(userId: number)
	local record = trapped[userId]
	if not record then
		return
	end
	trapped[userId] = nil
	record.maid:Clean()
	if record.root.Parent then
		record.root.Anchored = record.wasAnchored
	end
end

local function applyTrap(victimId: number, ownerId: number)
	local root, humanoid = alive(victimId)
	if not root or trapped[victimId] then
		return
	end
	local record = { root = root, wasAnchored = root.Anchored, maid = Maid.new() }
	trapped[victimId] = record
	root.Anchored = true
	record.maid:Give(humanoid.Died:Connect(function()
		releaseTrap(victimId)
	end))
	local player = Actors.getPlayer(victimId)
	if player then
		record.maid:Give(player.CharacterRemoving:Connect(function()
			releaseTrap(victimId)
		end))
		Net.fire("Trapped", player, { seconds = PvpRules.trapStunSeconds })
	end
	task.delay(PvpRules.trapStunSeconds, function()
		if trapped[victimId] == record then
			releaseTrap(victimId)
		end
	end)
	CarryService.notify(
		ownerId,
		`{Actors.getName(victimId)} got stuck in your Yolk Trap!`,
		"success"
	)
end

function DefenseService.isTrapped(userId: number): boolean
	return trapped[userId] ~= nil
end

function DefenseService.trapCost(userId: number): number
	local data = DataService.getByUserId(userId)
	return PvpRules.trapCost(data and data.lastIncomePerSec)
end

function DefenseService.activeTrapCount(userId: number): number
	return #(traps[userId] or {})
end

local function removeTrapAt(ownerId: number, index: number)
	local list = traps[ownerId]
	if not list then
		return
	end
	local trap = table.remove(list, index)
	if trap and trap.part then
		trap.part:Destroy()
	end
	if #list == 0 then
		traps[ownerId] = nil
	end
end

local function groundY(pos: Vector3): number
	local exclude = { effectsFolder(), workspace:FindFirstChild(Names.Bots) }
	for _, player in Players:GetPlayers() do
		table.insert(exclude, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else 0
end

-- Pasang trap. free = true melewati biaya (admin). Mengembalikan true, atau false + pesan galat.
function DefenseService.placeTrap(userId: number, pos: Vector3, free: boolean?): (boolean, string?)
	local function fail(message: string)
		CarryService.notify(userId, message, "error")
		return false, message
	end
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	local root = alive(userId)
	if not (data and plot and root) then
		return fail("You can't place a trap right now.")
	end
	if inSpawnPad(pos) then
		return fail("You can't place a trap on the spawn pad!")
	end
	if PlotService.distanceToPlot(plot, pos) > PvpRules.trapMaxPlotDistance then
		return fail("Place the trap closer to your Coop!")
	end
	if (pos - root.Position).Magnitude > PvpRules.trapMaxOwnerDistance then
		return fail("That spot is too far from you!")
	end
	local maxTraps = PvpRules.maxTraps(data.penLevel)
	if DefenseService.activeTrapCount(userId) >= maxTraps then
		return fail(`You can only have {maxTraps} active trap{if maxTraps > 1 then "s" else ""}.`)
	end
	local cost = DefenseService.trapCost(userId)
	if not free and not CurrencyService.trySpend(userId, "cash", cost) then
		return fail(`Not enough cash! A trap costs {NumberFormat.fmtMoney(cost)}.`)
	end

	local size = PvpRules.trapSize
	local part = Instance.new("Part")
	part.Name = "YolkTrap"
	part.Size = Vector3.new(size, 0.3, size)
	part.Color = Color3.fromRGB(255, 205, 40)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.2
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(pos.X, groundY(pos) + 0.2, pos.Z)
	part:SetAttribute(Attr.TrapOwner, userId)
	CollectionService:AddTag(part, Tags.Trap)
	part.Parent = effectsFolder()

	local list = traps[userId]
	if not list then
		list = {}
		traps[userId] = list
	end
	table.insert(list, {
		part = part,
		ownerId = userId,
		expireAt = os.clock() + PvpRules.trapLifetime,
	})
	CarryService.notify(userId, `Trap placed! ({#list}/{maxTraps} active)`, "success")
	return true
end

local function tickTraps()
	if next(traps) == nil then
		return
	end
	local now = os.clock()
	local entries = DataService.all()
	local radius = PvpRules.trapTriggerRadius
	for ownerId, list in traps do
		for i = #list, 1, -1 do
			local trap = list[i]
			if now >= trap.expireAt or not trap.part.Parent then
				removeTrapAt(ownerId, i)
			else
				local center = trap.part.Position
				for _, entry in entries do
					local id = entry.userId
					if id ~= ownerId and not trapped[id] and CarryService.isCarrying(id) then
						local root = alive(id)
						if root and not inSpawnPad(root.Position) then
							local dx, dz = root.Position.X - center.X, root.Position.Z - center.Z
							if
								dx * dx + dz * dz <= radius * radius
								and math.abs(root.Position.Y - center.Y) <= 8
							then
								removeTrapAt(ownerId, i)
								applyTrap(id, ownerId)
								break
							end
						end
					end
				end
			end
		end
	end
end

-- ===== Shell Shield =====

function DefenseService.getShieldRemaining(userId: number): number
	local shield = shields[userId]
	if not shield then
		return 0
	end
	return math.max(0, shield.untilAt - Clock.now())
end

function DefenseService.endShield(userId: number)
	local shield = shields[userId]
	if not shield then
		return
	end
	shields[userId] = nil
	if shield.dome then
		shield.dome:Destroy()
	end
	if shield.plot then
		shield.plot:SetAttribute(Attr.ShieldUntil, 0)
	end
end

function DefenseService.activateShield(userId: number): (boolean, string?)
	local function fail(message: string)
		CarryService.notify(userId, message, "error")
		return false, message
	end
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	if not (data and plot) then
		return fail("You can't use the shield right now.")
	end
	if shields[userId] then
		return fail("Your Shell Shield is already active!")
	end
	local now = Clock.now()
	if (data.shieldReadyAt or 0) > now then
		return fail(`Shell Shield recharging: {NumberFormat.fmtTime(data.shieldReadyAt - now)}`)
	end

	local duration = PvpRules.shieldDuration(data.penLevel)
	data.shieldReadyAt = now + PvpRules.shieldCooldown
	StateReplicator.set(userId, "shieldReadyAt", data.shieldReadyAt)
	plot:SetAttribute(Attr.ShieldUntil, now + duration)

	local floor = PlotService.getFloor(plot)
	local dome = Instance.new("Part")
	dome.Name = "ShellShield"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(DOME_DIAMETER, DOME_DIAMETER, DOME_DIAMETER)
	dome.Color = Color3.fromRGB(120, 220, 255)
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 0.6
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.CastShadow = false
	dome.Position = Vector3.new(floor.Position.X, 0, floor.Position.Z)
	dome:SetAttribute(Attr.OwnerUserId, userId)
	CollectionService:AddTag(dome, Tags.Shield)
	dome.Parent = effectsFolder()

	shields[userId] = { dome = dome, plot = plot, untilAt = now + duration }
	CarryService.notify(userId, `Shell Shield on for {duration} seconds!`, "success")
	return true
end

-- Dorong pemain non-pemilik keluar dari persegi plot (lewat sisi terdekat).
local function pushIntruders(ownerId: number, shield)
	local floor = PlotService.getFloor(shield.plot)
	if not floor then
		return
	end
	local half = Layout.plotSize / 2
	for _, entry in DataService.all() do
		local id = entry.userId
		if id ~= ownerId then
			local root = Actors.getRoot(id)
			if root then
				local localPos = floor.CFrame:PointToObjectSpace(root.Position)
				if
					PvpRules.insideSquare(localPos.X, localPos.Z, half)
					and math.abs(localPos.Y) < 60
				then
					local nx, nz =
						PvpRules.pushOutside(localPos.X, localPos.Z, half, SHIELD_PUSH_MARGIN)
					local world = floor.CFrame:PointToWorldSpace(Vector3.new(nx, localPos.Y, nz))
					AntiExploit.grace(id, 1, "shield_push")
					root.CFrame = CFrame.new(world) * (root.CFrame - root.CFrame.Position)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end
end

local function tickShields()
	if next(shields) == nil then
		return
	end
	local now = os.clock()
	local push = now - lastPush >= PvpRules.shieldPushInterval - 0.02
	if push then
		lastPush = now
	end
	local list = {}
	for ownerId, shield in shields do
		table.insert(list, { ownerId, shield })
	end
	for _, item in list do
		local ownerId, shield = item[1], item[2]
		if Clock.now() >= shield.untilAt or not shield.dome.Parent then
			DefenseService.endShield(ownerId)
		elseif push then
			pushIntruders(ownerId, shield)
		end
	end
end

function DefenseService.stats()
	local trapCount, trappedCount, shieldCount, stunCount = 0, 0, 0, 0
	for _, list in traps do
		trapCount += #list
	end
	for _ in trapped do
		trappedCount += 1
	end
	for _ in shields do
		shieldCount += 1
	end
	for _ in stunned do
		stunCount += 1
	end
	return {
		traps = trapCount,
		trapped = trappedCount,
		shields = shieldCount,
		stunned = stunCount,
	}
end

-- ===== Lifecycle =====

local function onJoin(ctx)
	local player = ctx.player
	if not player then
		return
	end
	local userId = ctx.userId
	if panMaids[userId] then
		panMaids[userId]:Clean()
	end
	local maid = Maid.new()
	panMaids[userId] = maid
	maid:Give(player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Backpack dibuat ulang saat respawn
		if player.Character == character then
			givePan(player)
		end
	end))
	task.spawn(givePan, player)
end

local function onLeaving(ctx)
	local userId = ctx.userId
	releaseTrap(userId)
	stunned[userId] = nil
	swingAt[userId] = nil
	while traps[userId] do
		removeTrapAt(userId, 1)
	end
	DefenseService.endShield(userId)
	local maid = panMaids[userId]
	if maid then
		maid:Clean()
		panMaids[userId] = nil
	end
	if ctx.player then
		removePans(ctx.player:FindFirstChildOfClass("Backpack"))
		removePans(ctx.player.Character)
	end
end

function DefenseService.Init()
	PlayerLifecycle.onJoin("DefenseService", 100, onJoin)
	-- order 30: sesudah Carry (10) dan Steal (20); trap/anchor selalu dilepas sebelum profil dilepas.
	PlayerLifecycle.onLeaving("DefenseService", 30, onLeaving)

	TestBridge.register("defense.swing", function(userId)
		local ok, result = DefenseService.swing(userId)
		return { ok = ok, result = result }
	end)
	TestBridge.register("defense.trap", function(userId, x, y, z)
		local ok, err = DefenseService.placeTrap(userId, Vector3.new(x, y, z))
		return { ok = ok, err = err }
	end)
	TestBridge.register("defense.shield", function(userId)
		local ok, err = DefenseService.activateShield(userId)
		return { ok = ok, err = err }
	end)
	TestBridge.register("defense.stats", function()
		return DefenseService.stats()
	end)

	AdminService.register("shield", function(player)
		local data = DataService.getByUserId(player.UserId)
		if not data then
			return "Data belum dimuat"
		end
		data.shieldReadyAt = 0
		local ok, err = DefenseService.activateShield(player.UserId)
		return if ok then "Shield aktif" else tostring(err)
	end)
	AdminService.register("trap", function(player)
		local root = alive(player.UserId)
		if not root then
			return "Karakter tidak ada"
		end
		local pos = root.Position + root.CFrame.LookVector * 5
		local ok, err = DefenseService.placeTrap(player.UserId, pos, true)
		return if ok then "Trap dipasang (gratis)" else tostring(err)
	end)
end

function DefenseService.Start()
	Net.on("SwingPan", Check.args(), function(player)
		DefenseService.swing(player.UserId)
	end)
	Net.on("PlaceTrap", Check.args(Check.vec3), function(player, pos)
		DefenseService.placeTrap(player.UserId, pos)
	end)
	Net.on("ActivateShield", Check.args(), function(player)
		DefenseService.activateShield(player.UserId)
	end)

	Clock.every10Hz(function()
		tickTraps()
		tickShields()
	end)
end

return DefenseService
