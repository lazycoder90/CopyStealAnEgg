--!nonstrict
-- GuardianService: 12 Nestwarden kinematik (Anchored, PivotTo tiap Heartbeat), satu per zona.
-- Siklus: Sleep -> Alert -> Chase -> Return -> Sleep. Gerak dan waktu memakai WAKTU NYATA (dt Heartbeat / os.clock),
-- tidak pernah Clock.timeScale. Guardian tidak pernah melewati Hearth Line (lihat Logic/GuardianChase).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuardianConfig = require(Shared.Config.GuardianConfig)
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local GuardianChase = require(Shared.Logic.GuardianChase)
local Formulas = require(Shared.Logic.Formulas)
local GuardianModels = require(Shared.GuardianModels)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local GameEvents = require(Systems.GameEvents)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AntiExploit = require(script.Parent.AntiExploit)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local GuardianService = {}

local STATES = { Sleep = true, Alert = true, Chase = true, Return = true }
local INVARIANT_FLOOR_MARGIN = 3 -- pemeriksa: posisi tidak boleh di bawah Hearth Line + 3

local guardians = {} -- [zone] = { zone, model, state, x, z, fx, fz, target, chaseTime, wakeAt, home }
local stunned = {} -- [userId] = true selama WalkSpeed ditahan 0
local caughtTotal = 0

local function ensureStats(data)
	if type(data.stats) ~= "table" then
		data.stats = {}
	end
	return data.stats
end

local function params(speed: number, catchRadius: number)
	return {
		speed = speed,
		catchRadius = catchRadius,
		hearthLineZ = Layout.hearthLineZ,
		minZ = GuardianConfig.minZ(),
	}
end

local function chaseSpeed(g): number
	local zone = Zones.get(g.zone)
	return Formulas.walkSpeed(zone.guardianSpeedStat) * GuardianConfig.chaseSpeedFactor
end

local function setState(g, state: string)
	g.state = state
	GuardianModels.setState(g.model, state)
end

local function place(g)
	local pos = Vector3.new(g.x, 0, g.z)
	g.model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(g.fx, 0, g.fz)))
end

local function sleepNow(g)
	g.target = nil
	g.chaseTime = 0
	g.x, g.z = g.homeX, g.homeZ
	g.fx, g.fz = 0, -1
	setState(g, "Sleep")
	place(g)
end

-- Jarak horizontal guardian ke pemain (nil bila tidak punya root).
local function distanceTo(g, userId: number): number?
	local root = Actors.getRoot(userId)
	if not root then
		return nil
	end
	local dx, dz = root.Position.X - g.x, root.Position.Z - g.z
	return math.sqrt(dx * dx + dz * dz)
end

local function tutorialBlocks(userId: number): boolean
	if not GuardianConfig.tutorialIgnore then
		return false
	end
	local TutorialService = require(script.Parent.TutorialService) -- lazy: hindari siklus require
	return TutorialService.isActive(userId)
end

local function fireAlert(g)
	local payload = { zone = g.zone, guardianId = Zones.get(g.zone).guardian.id }
	for _, player in Players:GetPlayers() do
		local d = distanceTo(g, player.UserId)
		if d and d <= GuardianConfig.alertShakeRadius then
			Net.fire("GuardianAlert", player, payload)
		end
	end
end

-- Membangunkan guardian zona tertentu dengan target userId. Mengembalikan true bila target diterima.
function GuardianService.wake(zone: number, userId: number, grand: boolean?): boolean
	local g = guardians[zone]
	if not g or not CarryService.isCarrying(userId) then
		return false
	end
	if tutorialBlocks(userId) then
		return false
	end
	if g.state == "Chase" or g.state == "Alert" then
		-- Sudah mengejar: pindah target hanya jika pembawa baru lebih dekat.
		if g.target ~= userId then
			local dNew = distanceTo(g, userId)
			local dOld = g.target and distanceTo(g, g.target)
			if dNew and (dOld == nil or dNew < dOld) then
				g.target = userId
			end
		end
		return true
	end
	g.target = userId
	g.chaseTime = 0
	g.wakeAt = os.clock()
		+ (if grand then GuardianConfig.wakeDelayGrand else GuardianConfig.wakeDelay)
	setState(g, "Alert")
	fireAlert(g)
	return true
end

function GuardianService.sleep(zone: number)
	local g = guardians[zone]
	if g then
		sleepNow(g)
	end
end

local function stun(userId: number, humanoid: Humanoid)
	if stunned[userId] then
		return
	end
	local previous = humanoid.WalkSpeed
	stunned[userId] = true
	humanoid.WalkSpeed = 0
	task.delay(GuardianConfig.catchStunSeconds, function()
		stunned[userId] = nil
		-- Pulihkan hanya jika Humanoid masih ada dan belum diubah pihak lain.
		if humanoid.Parent and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = previous
		end
	end)
end

local function doCatch(g, userId: number)
	local root = Actors.getRoot(userId)
	local humanoid = Actors.getHumanoid(userId)
	local dirX, dirZ = 0, 1
	if root then
		local dx, dz = root.Position.X - g.x, root.Position.Z - g.z
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 1e-6 then
			dirX, dirZ = dx / len, dz / len
		end
	end

	CarryService.forceReturn(userId, "caught")
	CarryService.setPickupImmunity(userId, GuardianConfig.catchImmunitySeconds)
	local data = DataService.getByUserId(userId)
	if data then
		local stats = ensureStats(data)
		stats.caught = (stats.caught or 0) + 1
		StateReplicator.set(userId, "stats.caught", stats.caught)
	end
	AntiExploit.grace(userId, GuardianConfig.catchGraceSeconds, "caught")
	caughtTotal += 1

	local player = Players:GetPlayerByUserId(userId)
	if player then
		local knock = Vector3.new(
			dirX * GuardianConfig.knockHorizontal,
			GuardianConfig.knockUp,
			dirZ * GuardianConfig.knockHorizontal
		)
		Net.fire("Caught", player, { knock = knock, zone = g.zone })
	end
	if humanoid and humanoid.Health > 0 then
		stun(userId, humanoid)
	end
	GameEvents.PlayerCaught:Fire({ userId = userId, zone = g.zone })

	g.target = nil
	setState(g, "Return")
end

local function targetPoint(userId: number?)
	local root = userId and Actors.getRoot(userId)
	if not root then
		return nil
	end
	return { x = root.Position.X, z = root.Position.Z }
end

local function stepChase(g, dt: number)
	local userId = g.target
	local target = targetPoint(userId)
	local carrying = userId ~= nil and CarryService.isCarrying(userId)
	g.chaseTime += dt
	local back = GuardianChase.shouldReturn({ x = g.x, z = g.z }, {
		target = target,
		targetCarrying = carrying,
		hearthLineZ = Layout.hearthLineZ,
		homeX = g.homeX,
		homeZ = g.homeZ,
		leash = GuardianConfig.leash,
		chaseTime = g.chaseTime,
		maxChaseSeconds = GuardianConfig.maxChaseSeconds,
	})
	if back then
		g.target = nil
		setState(g, "Return")
		return
	end

	local humanoid = Actors.getHumanoid(userId)
	local walk = humanoid and humanoid.WalkSpeed or 16
	local radius = GuardianConfig.catchRadius(walk)
	local nextState, caught =
		GuardianChase.step({ x = g.x, z = g.z }, target, dt, params(chaseSpeed(g), radius))
	local dx, dz = nextState.x - g.x, nextState.z - g.z
	if dx * dx + dz * dz > 1e-8 then
		local len = math.sqrt(dx * dx + dz * dz)
		g.fx, g.fz = dx / len, dz / len
	end
	g.x, g.z = nextState.x, nextState.z
	place(g)
	if caught then
		doCatch(g, userId)
	end
end

local function stepReturn(g, dt: number)
	local nextState, arrived = GuardianChase.moveToward(
		{ x = g.x, z = g.z },
		g.homeX,
		g.homeZ,
		dt,
		params(chaseSpeed(g) * GuardianConfig.returnSpeedFactor, 0)
	)
	local dx, dz = nextState.x - g.x, nextState.z - g.z
	if dx * dx + dz * dz > 1e-8 then
		local len = math.sqrt(dx * dx + dz * dz)
		g.fx, g.fz = dx / len, dz / len
	end
	g.x, g.z = nextState.x, nextState.z
	place(g)
	if arrived then
		sleepNow(g)
	end
end

local function stepAlert(g)
	local userId = g.target
	if not (userId and CarryService.isCarrying(userId) and Actors.getRoot(userId)) then
		g.target = nil
		setState(g, "Return")
		return
	end
	-- Menghadap target saat bersiap.
	local target = targetPoint(userId)
	local dx, dz = target.x - g.x, target.z - g.z
	local len = math.sqrt(dx * dx + dz * dz)
	if len > 1e-6 then
		g.fx, g.fz = dx / len, dz / len
		place(g)
	end
	if os.clock() >= g.wakeAt then
		g.chaseTime = 0
		setState(g, "Chase")
	end
end

local function update(dt: number)
	for _, g in guardians do
		-- Guardian tidur tidak butuh kerja per frame (activeRadius hanya relevan untuk yang terjaga).
		if g.state ~= "Sleep" then
			if g.state == "Alert" then
				stepAlert(g)
			elseif g.state == "Chase" then
				stepChase(g, dt)
			elseif g.state == "Return" then
				stepReturn(g, dt)
			end
		end
	end
end

local function build()
	local folder = workspace:WaitForChild(Types.Names.Guardians)
	for _, zone in Zones.list do
		local model = GuardianModels.build(zone)
		local hx, hz = GuardianConfig.home(zone.index)
		local g = {
			zone = zone.index,
			model = model,
			state = "Sleep",
			x = hx,
			z = hz,
			fx = 0,
			fz = -1,
			homeX = hx,
			homeZ = hz,
			target = nil,
			chaseTime = 0,
			wakeAt = 0,
		}
		guardians[zone.index] = g
		model.Parent = folder
		place(g)
	end
end

function GuardianService.getState(zone: number): string?
	local g = guardians[zone]
	return g and g.state
end

function GuardianService.Init()
	build()

	PlayerLifecycle.onLeaving("GuardianService", 40, function(ctx)
		stunned[ctx.userId] = nil
		for _, g in guardians do
			if g.target == ctx.userId then
				g.target = nil
				if g.state == "Alert" or g.state == "Chase" then
					setState(g, "Return")
				end
			end
		end
	end)

	InvariantChecker.registerWorld("Guardians", function()
		local out = {}
		local count = 0
		for zone, g in guardians do
			count += 1
			if not STATES[g.state] then
				table.insert(out, `guardian {zone} state tidak valid: {tostring(g.state)}`)
			end
			if g.model:GetAttribute(Types.Attr.GuardianState) ~= g.state then
				table.insert(out, `guardian {zone} atribut state tidak sinkron`)
			end
			if g.z < Layout.hearthLineZ + INVARIANT_FLOOR_MARGIN then
				table.insert(out, `guardian {zone} melewati Hearth Line: z={g.z}`)
			end
			if g.x ~= g.x or g.z ~= g.z then
				table.insert(out, `guardian {zone} posisi NaN`)
			end
		end
		if count ~= Zones.count then
			table.insert(out, `jumlah guardian {count} != {Zones.count}`)
		end
		return out
	end)

	TestBridge.register("guardian.state", function(zone)
		return GuardianService.getState(zone)
	end)
	TestBridge.register("guardian.info", function(zone)
		local g = guardians[zone]
		return g
			and { state = g.state, x = g.x, z = g.z, target = g.target, chaseTime = g.chaseTime }
	end)
	TestBridge.register("guardian.wake", function(zone, userId)
		return GuardianService.wake(zone, userId)
	end)
	TestBridge.register("guardian.sleep", function(zone)
		GuardianService.sleep(zone)
		return true
	end)
	TestBridge.register("guardian.stats", function()
		local counts =
			{ Sleep = 0, Alert = 0, Chase = 0, Return = 0, total = 0, caught = caughtTotal }
		for _, g in guardians do
			counts[g.state] += 1
			counts.total += 1
		end
		return counts
	end)

	AdminService.register("guardian", function(_, args)
		local zone = tonumber(args[1])
		local action = string.lower(args[2] or "")
		if not (zone and guardians[zone] and (action == "wake" or action == "sleep")) then
			return "Pakai: guardian <1..12> wake|sleep"
		end
		if action == "sleep" then
			GuardianService.sleep(zone)
			return `Guardian {zone} tidur`
		end
		-- Wake admin: target = pembawa telur terdekat di mana pun.
		for _, entry in DataService.all() do
			if
				CarryService.isCarrying(entry.userId) and GuardianService.wake(zone, entry.userId)
			then
				return `Guardian {zone} bangun`
			end
		end
		return "Tidak ada pembawa telur (atau masih tutorial)"
	end)
end

function GuardianService.Start()
	GameEvents.EggGrabbed:Connect(function(payload)
		GuardianService.wake(payload.zone, payload.userId, payload.grand)
	end)
	RunService.Heartbeat:Connect(update)
end

return GuardianService
