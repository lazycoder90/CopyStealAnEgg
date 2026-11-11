--!nonstrict
-- RaceService: Dash Derby (docs/PLAN.md 4.10, docs/CHANGES.md #13).
-- Jadwal (waktu-game, Clock.every1Hz): Idle -> Countdown -> Open -> Closed (podium) -> Idle.
-- Lintasan (start, 6 checkpoint, finish) dibangun saat Open di Workspace.Effects dan dihapus saat Closed.
-- Persilangan gerbang dihitung SERVER dari sampel posisi 10 Hz WAKTU NYATA (segmen vs bidang gerbang,
-- RaceMath); gerbang harus dilewati berurutan. Hadiah trophy diberikan SEKALI saat race ditutup.
-- Guardian TIDAK ditidurkan (CHANGES #13). Pickup telur dunia di zona race dikunci saat Open.
-- TestBridge: race.state, race.course, race.attempt, race.podium, race.start, race.close, race.skip, race.reset.
-- Admin: race start [zona] | race close | race skip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local RaceConfig = require(Shared.Config.RaceConfig)
local Zones = require(Shared.Config.Zones)
local RaceMath = require(Shared.Logic.RaceMath)
local RNG = require(Shared.Logic.RNG)
local TravelMath = require(Shared.Logic.TravelMath)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CarryService = require(script.Parent.CarryService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)

local Attr, Tags, Names = Types.Attr, Types.Tags, Types.Names

local RaceService = {}

local HALF_WIDTH = Layout.laneWidth / 2

local phase = "Idle"
local remaining = RaceConfig.intervalSeconds -- detik waktu-game sampai fase berikutnya
local raceZone: number? = nil
local raceId = 0
local course: Model? = nil
local rng = RNG.new(os.time())
local sinceBroadcast = 0

local tracks = {} -- [userId] = { root, x, z, t } sampel posisi terakhir (waktu nyata)
local attempts = {} -- [userId] = { last, startT } percobaan berjalan
local results = {} -- [userId] = { best } waktu terbaik pada race ini
local podium = nil -- { RacePodiumRow } setelah Closed
local rewards = {} -- [userId] = { rank, trophies, record } setelah Closed

-- ===== Util =====

local function zoneName(): string?
	return raceZone and Zones.get(raceZone).name
end

local function clearPlayerState(userId: number)
	tracks[userId] = nil
	attempts[userId] = nil
end

local function clearRound()
	table.clear(tracks)
	table.clear(attempts)
	table.clear(results)
end

local function notify(userId: number, message: string, kind: string)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

-- ===== Siaran RaceState =====

local function payloadFor(userId: number)
	local payload = {
		phase = phase,
		remaining = math.max(0, math.ceil(remaining)),
	}
	if phase ~= "Idle" then
		payload.zone = raceZone
		payload.zoneName = zoneName()
	end
	if phase == "Open" or phase == "Closed" then
		local result = results[userId]
		payload.myBest = result and result.best
	end
	if phase == "Open" then
		local attempt = attempts[userId]
		if attempt and attempt.last >= 0 and attempt.startT then
			payload.myAttempt = {
				checkpoint = attempt.last,
				elapsedSeconds = os.clock() - attempt.startT,
			}
		end
	end
	if phase == "Closed" then
		payload.podium = podium
		local mine = rewards[userId]
		payload.myRank = mine and mine.rank
		payload.myTrophies = mine and mine.trophies
		payload.myTrophyTotal = CurrencyService.get(userId, "trophies")
	end
	return payload
end

local function sendTo(player: Player)
	Net.fire("RaceState", player, payloadFor(player.UserId))
end

local function broadcast()
	sinceBroadcast = 0
	for _, player in Players:GetPlayers() do
		sendTo(player)
	end
end

-- ===== Lintasan =====

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function gateLabel(index: number): string
	if index == 0 then
		return "START"
	elseif index == RaceMath.finishIndex then
		return "FINISH"
	end
	return `CHECKPOINT {index}`
end

local function newPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildGate(parent: Instance, zone: number, index: number)
	local z = RaceMath.gateZ(zone, index)
	local rgb = RaceConfig.gateColor
	if index == 0 then
		rgb = RaceConfig.startColor
	elseif index == RaceMath.finishIndex then
		rgb = RaceConfig.finishColor
	end
	local tint = color(rgb)
	local width = RaceConfig.pillarWidth
	local height = RaceConfig.gateHeight

	local gate = Instance.new("Model")
	gate.Name = `Gate{index}`
	for _, side in { -1, 1 } do
		local pillar = newPart(
			"Pillar",
			Vector3.new(width, height + 2, width),
			CFrame.new(side * (HALF_WIDTH - width / 2), (height + 2) / 2, z),
			gate
		)
		pillar.Color = tint
		pillar.Material = Enum.Material.SmoothPlastic
	end
	local ring = newPart(
		"Ring",
		Vector3.new(Layout.laneWidth - 2 * width, 2, 2),
		CFrame.new(0, height, z),
		gate
	)
	ring.Color = tint
	ring.Material = Enum.Material.Neon
	ring:AddTag(Tags.RaceGate)
	ring:SetAttribute(Attr.RaceId, raceId)
	ring:SetAttribute(Attr.GateIndex, index)

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(180, 40)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 400
	board.Adornee = ring
	board.Parent = ring
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextColor3 = tint
	label.TextStrokeTransparency = 0
	label.Text = gateLabel(index)
	label.Parent = board
	gate.Parent = parent
end

local function destroyCourse()
	if course then
		course:Destroy()
		course = nil
	end
end

local function buildCourse()
	destroyCourse()
	local effects = workspace:FindFirstChild(Names.Effects)
	if not effects then
		effects = Instance.new("Folder")
		effects.Name = Names.Effects
		effects.Parent = workspace
	end
	local model = Instance.new("Model")
	model.Name = RaceConfig.courseName
	model:SetAttribute(Attr.RaceId, raceId)
	for index = 0, RaceMath.finishIndex do
		buildGate(model, raceZone, index)
	end
	model.Parent = effects
	course = model
end

-- ===== Hadiah =====

local function settle()
	local entries = {}
	for userId, result in results do
		if result.best and DataService.getByUserId(userId) then
			table.insert(entries, { userId = userId, time = result.best })
		end
	end
	local ranked = RaceMath.rank(entries)
	podium = {}
	table.clear(rewards)
	local key = tostring(raceZone)
	for rank, entry in ranked do
		local userId = entry.userId
		local data = DataService.getByUserId(userId)
		data.raceBest = data.raceBest or {}
		local record = RaceMath.beatsRecord(entry.time, data.raceBest[key])
		local amount = RaceMath.trophies(raceZone, rank, record)
		if record then
			data.raceBest[key] = entry.time
			StateReplicator.set(userId, "raceBest." .. key, entry.time)
		end
		CurrencyService.add(userId, "trophies", amount)
		rewards[userId] = { rank = rank, trophies = amount, record = record }
		notify(userId, `+{RaceMath.commas(amount)} Trophies`, "success")
		if rank <= #RaceConfig.rankMultipliers then
			table.insert(podium, {
				userId = userId,
				name = Actors.getName(userId),
				timeSeconds = entry.time,
				trophies = amount,
			})
		end
	end
end

-- ===== Fase =====

local function enterIdle()
	phase = "Idle"
	remaining = RaceConfig.intervalSeconds
	raceZone = nil
	podium = nil
	table.clear(rewards)
	clearRound()
	destroyCourse()
	broadcast()
end

local function pickZone(): number
	local top = 0
	for _, entry in DataService.all() do
		top = math.max(top, SpeedService.getEffectiveSpeed(entry.userId))
	end
	return RaceMath.pickZone(RaceMath.maxZoneFor(top), rng)
end

local function enterCountdown(zone: number?)
	phase = "Countdown"
	remaining = RaceConfig.countdownSeconds
	raceZone = zone or pickZone()
	broadcast()
end

local function enterOpen(zone: number?)
	if not raceZone or zone then
		raceZone = zone or pickZone()
	end
	raceId += 1
	clearRound()
	podium = nil
	table.clear(rewards)
	phase = "Open"
	remaining = RaceConfig.openSeconds
	buildCourse()
	local info = Zones.get(raceZone)
	AnnouncementService.broadcast({
		AnnouncementService.text(RaceConfig.announcePrefix),
		AnnouncementService.text(info.name, info.accentRgb),
		AnnouncementService.text(RaceConfig.announceSuffix),
	})
	broadcast()
end

local function enterClosed()
	phase = "Closed"
	remaining = RaceConfig.podiumSeconds
	destroyCourse()
	settle()
	table.clear(tracks)
	table.clear(attempts)
	broadcast()
end

local function advancePhase()
	if phase == "Idle" then
		enterCountdown()
	elseif phase == "Countdown" then
		enterOpen()
	elseif phase == "Open" then
		enterClosed()
	else
		enterIdle()
	end
end

function RaceService.getState()
	return { phase = phase, remaining = remaining, zone = raceZone, raceId = raceId }
end

-- ===== Deteksi gerbang (10 Hz waktu nyata) =====

local function onFinish(userId: number, seconds: number)
	local result = results[userId]
	if not result then
		result = {}
		results[userId] = result
	end
	local improved = result.best == nil or seconds < result.best
	if improved then
		result.best = seconds
	end
	notify(
		userId,
		`Finished in {RaceMath.formatTime(seconds)}{if improved then " (best!)" else ""}`,
		"info"
	)
end

local function sampleUser(userId: number, now: number)
	local root = Actors.getRoot(userId)
	local humanoid = Actors.getHumanoid(userId)
	if not root or (humanoid and humanoid.Health <= 0) then
		clearPlayerState(userId)
		return
	end
	local pos = root.Position
	local track = tracks[userId]
	if not track or track.root ~= root then
		attempts[userId] = nil -- karakter baru (mati/respawn): percobaan batal
		tracks[userId] = { root = root, x = pos.X, z = pos.Z, t = now }
		return
	end
	-- Lompatan tak wajar (teleport/lag besar) tidak menghitung persilangan; sampel baru jadi acuan.
	local dx, dz = pos.X - track.x, pos.Z - track.z
	local walk = (humanoid and humanoid.WalkSpeed or 0) * RaceConfig.speedTolerance
	local plausible = TravelMath.samplePlausible(math.sqrt(dx * dx + dz * dz), walk, now - track.t)
	local crossed = if plausible
		then RaceMath.crossings(raceZone, track.x, track.z, pos.X, pos.Z, HALF_WIDTH)
		else {}
	if #crossed > 0 then
		local attempt = attempts[userId]
		if not attempt then
			attempt = { last = -1 }
			attempts[userId] = attempt
		end
		local last, events = RaceMath.advance(attempt.last, crossed)
		attempt.last = last
		for _, event in events do
			local crossTime = track.t + event.t * (now - track.t)
			if event.kind == "start" then
				attempt.startT = crossTime
			elseif event.kind == "finish" and attempt.startT then
				onFinish(userId, crossTime - attempt.startT)
				attempt.startT = nil
			end
		end
	end
	track.x, track.z, track.t = pos.X, pos.Z, now
end

local function sampleAll()
	if phase ~= "Open" or not raceZone then
		return
	end
	local now = os.clock()
	for _, entry in DataService.all() do
		sampleUser(entry.userId, now)
	end
end

-- ===== Lifecycle / API =====

local function tick(dt: number)
	remaining -= dt
	sinceBroadcast += dt
	if remaining <= 0 then
		advancePhase()
		return
	end
	if phase == "Open" or sinceBroadcast >= RaceConfig.broadcastEvery then
		broadcast()
	end
end

-- Tes/admin: mulai Open sekarang (zona opsional). Mengembalikan true bila berhasil.
function RaceService.forceOpen(zone: number?): boolean
	if phase == "Open" then
		return false
	end
	if zone and not (zone % 1 == 0 and zone >= 1 and zone <= Zones.count) then
		return false
	end
	enterOpen(zone)
	return true
end

function RaceService.forceClose(): boolean
	if phase ~= "Open" then
		return false
	end
	enterClosed()
	return true
end

-- Tes/admin: kembali ke Idle tanpa hadiah (menghapus lintasan).
function RaceService.reset()
	enterIdle()
end

function RaceService.Init()
	CarryService.addPickupGuard("race", function(_, entity)
		if phase == "Open" and raceZone and entity.zone == raceZone then
			return false, RaceConfig.lockedMessage
		end
		return true
	end)

	PlayerLifecycle.onLeaving("RaceService", 100, function(ctx)
		clearPlayerState(ctx.userId)
		results[ctx.userId] = nil
		rewards[ctx.userId] = nil
	end)

	InvariantChecker.registerWorld("race", function()
		local out = {}
		local gates = 0
		if course then
			for _, child in course:GetDescendants() do
				if child:HasTag(Tags.RaceGate) then
					gates += 1
				end
			end
		end
		if phase == "Open" then
			if gates ~= RaceMath.gateCount then
				table.insert(out, `Open dengan {gates} gerbang`)
			end
			if not raceZone then
				table.insert(out, "Open tanpa zona")
			end
		elseif course then
			table.insert(out, `lintasan ada saat fase {phase}`)
		end
		return out
	end)
	InvariantChecker.register("raceBest", function(entry)
		local out = {}
		for key, value in entry.data.raceBest or {} do
			if type(value) ~= "number" or value ~= value or value <= 0 then
				table.insert(out, `raceBest[{key}] tidak valid: {tostring(value)}`)
			end
		end
		return out
	end)

	AdminService.register("race", function(_, args)
		local action = string.lower(args[1] or "")
		if action == "start" then
			local zone = tonumber(args[2])
			if not RaceService.forceOpen(zone) then
				return "Race sudah Open atau zona tidak valid (race start [1..12])"
			end
			return `Race Open di {zoneName()}`
		elseif action == "close" then
			if not RaceService.forceClose() then
				return "Race tidak sedang Open"
			end
			return "Race ditutup, hadiah dibagikan"
		elseif action == "skip" then
			advancePhase()
			return `Race fase: {phase}`
		end
		return "Pakai: race start [zona] | race close | race skip"
	end)

	TestBridge.register("race.state", function()
		return RaceService.getState()
	end)
	TestBridge.register("race.start", function(zone)
		return RaceService.forceOpen(zone)
	end)
	TestBridge.register("race.close", function()
		return RaceService.forceClose()
	end)
	TestBridge.register("race.skip", function()
		advancePhase()
		return phase
	end)
	TestBridge.register("race.reset", function()
		RaceService.reset()
		return true
	end)
	TestBridge.register("race.course", function()
		local gates = {}
		if course then
			for _, child in course:GetDescendants() do
				if child:HasTag(Tags.RaceGate) then
					local index = child:GetAttribute(Attr.GateIndex)
					gates[index + 1] = {
						index = index,
						x = child.Position.X,
						y = child.Position.Y,
						z = child.Position.Z,
						raceId = child:GetAttribute(Attr.RaceId),
					}
				end
			end
		end
		return { gates = gates, halfWidth = HALF_WIDTH, zone = raceZone }
	end)
	TestBridge.register("race.attempt", function(userId)
		local attempt = attempts[userId]
		local result = results[userId]
		return {
			last = attempt and attempt.last,
			elapsed = attempt and attempt.startT and (os.clock() - attempt.startT) or nil,
			best = result and result.best,
		}
	end)
	TestBridge.register("race.podium", function()
		return { podium = podium, rewards = rewards }
	end)

	Clock.every1Hz(tick)
	Clock.every10Hz(sampleAll)
end

function RaceService.Start()
	Net.on("ClientReady", Check.args(), function(player)
		sendTo(player)
	end)
end

return RaceService
