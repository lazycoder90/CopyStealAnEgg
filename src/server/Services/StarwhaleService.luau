--!nonstrict
-- StarwhaleService: rantai event Starwhale (docs/PLAN.md 4.11, disederhanakan: tanpa interior).
--  1. Astronomer Tilly di kios "Signal Tower" (hub) memberi puzzle Star Relay -> hadiah Star Compass.
--  2. Tiap StarwhaleConfig.intervalSeconds (waktu-game) seekor Starwhale muncul di zona 2..10 selama
--     stayingSeconds. Pemain berkompas yang mendekat menjadi "Found" dan mencari 3 telur aneh
--     (dirender KLIEN; posisi dihitung deterministik di StarwhaleMath, server memvalidasi jarak).
--  3. Selesai 3/3 -> pod Stardust muncul di sekitar paus (bersama). Tiap pod 3 pukulan; pemukul terakhir
--     mendapat Stardust 1..4; maksimal 3 pod per pemain per kunjungan.
--  4. Stardust dipakai di Tilly (trade): Orbital, Lucky, Speed, Growth.
-- Hook TestBridge: starwhale.state, .force(zone?), .end, .info(userId), .seed(n), .puzzle(userId) (SOLUSI,
-- hanya uji), .lastPayload(userId), .advance(dt).
-- Catatan: kemajuan per-kunjungan (found/telur/pod) disimpan di memori kunjungan menurut userId, jadi
-- tetap ada bila pemain keluar-masuk dalam kunjungan yang sama.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)
local Zones = require(Shared.Config.Zones)
local MutationLogic = require(Shared.Logic.MutationLogic)
local PipePuzzle = require(Shared.Logic.PipePuzzle)
local RNG = require(Shared.Logic.RNG)
local StarwhaleMath = require(Shared.Logic.StarwhaleMath)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags

local StarwhaleService = {}

local CFG = StarwhaleConfig
local WHALE_COLOR = { 190, 150, 255 }
local POD_COLOR = Color3.fromRGB(170, 120, 255)

local rng = RNG.new(os.time() + 91) -- zona/posisi paus, roll Stardust
local puzzleSeed = os.time() + 13
local puzzleCounter = 0

local visit = nil -- kunjungan aktif (lihat startVisit)
local nextIn = CFG.firstDelaySeconds -- detik waktu-game sampai penampakan berikut
local pushAcc = 0

local pending = {} -- [userId] = Puzzle (DENGAN solusi; tidak pernah dikirim ke klien)
local lastSent = {} -- [userId] = payload StarwhaleState terakhir (untuk uji)
local lastRequest = {} -- [userId] = os.clock() permintaan puzzle terakhir
local compassMaids = {} -- [userId] = Maid (koneksi respawn)

-- ===== util =====

local function effectsFolder(): Instance
	local folder = workspace:FindFirstChild(Names.Effects)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Names.Effects
		folder.Parent = workspace
	end
	return folder
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function hasCompass(data): boolean
	return data ~= nil and data.gear ~= nil and data.gear.compass == 1
end

local function fmtLeft(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function posVec(): { number }
	return { visit.pos.X, visit.pos.Y, visit.pos.Z }
end

local function newProgress()
	return { found = false, collected = {}, count = 0, done = false, cracked = 0, hits = 0 }
end

local function progressOf(userId: number)
	local prog = visit.progress[userId]
	if not prog then
		prog = newProgress()
		visit.progress[userId] = prog
	end
	return prog
end

local function oddPositionsFor(userId: number): { { number } }
	return StarwhaleMath.oddPositions(StarwhaleMath.oddSeed(visit.id, userId), posVec())
end

-- ===== payload =====

local function copyPuzzle(puzzle)
	local tiles = {}
	for r = 1, puzzle.size do
		tiles[r] = {}
		for c = 1, puzzle.size do
			local tile = puzzle.tiles[r][c]
			tiles[r][c] = { kind = tile.kind, rot = tile.rot }
		end
	end
	return {
		size = puzzle.size,
		tiles = tiles,
		source = { row = puzzle.source.row, col = puzzle.source.col },
		target = { row = puzzle.target.row, col = puzzle.target.col },
	}
end

local function buildState(userId: number)
	local data = DataService.getByUserId(userId)
	if not data then
		return nil
	end
	local payload = {
		phase = "Idle",
		remaining = 0,
		stardust = data.stardust,
		relayFixed = data.starwhale.relayFixed == true,
	}
	if not visit then
		return payload
	end
	payload.phase = "Sighted"
	payload.remaining = math.max(0, math.ceil(visit.remaining))
	payload.zone = visit.zone
	if hasCompass(data) then
		payload.target = { visit.pos.X, visit.pos.Y, visit.pos.Z }
	end
	local prog = visit.progress[userId]
	if prog and prog.found then
		payload.oddEggsTotal = CFG.oddCount
		payload.oddEggs = prog.count
		if prog.done then
			payload.phase = "Done"
		else
			payload.phase = "Found"
			local slots = {}
			for i, pos in oddPositionsFor(userId) do
				slots[i] = if prog.collected[i] then {} else pos
			end
			payload.oddPositions = slots
		end
	end
	return payload
end

local function sendState(userId: number, withPuzzle: boolean?)
	local payload = buildState(userId)
	if not payload then
		return
	end
	if withPuzzle and pending[userId] then
		payload.puzzle = copyPuzzle(pending[userId])
	end
	lastSent[userId] = payload
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("StarwhaleState", player, payload)
	end
end

local function pushAll()
	for _, entry in DataService.all() do
		sendState(entry.userId)
	end
end

-- ===== Star Compass (Tool) =====

local function buildCompass(): Tool
	local tool = Instance.new("Tool")
	tool.Name = CFG.compassToolName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Hold your Compass to track the Starwhale!"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(0.4, 1.6, 1.6)
	handle.Color = Color3.fromRGB(214, 170, 70)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	local face = Instance.new("Part")
	face.Name = "Face"
	face.Shape = Enum.PartType.Cylinder
	face.Size = Vector3.new(0.1, 1.3, 1.3)
	face.Color = Color3.fromRGB(40, 50, 100)
	face.Material = Enum.Material.Neon
	face.CanCollide = false
	face.Massless = true
	face.Parent = tool

	local needle = Instance.new("Part")
	needle.Name = "Needle"
	needle.Size = Vector3.new(0.12, 0.12, 1.1)
	needle.Color = Color3.fromRGB(255, 90, 90)
	needle.Material = Enum.Material.Neon
	needle.CanCollide = false
	needle.Massless = true
	needle.Parent = tool

	local faceJoint = Instance.new("Weld")
	faceJoint.Part0 = handle
	faceJoint.Part1 = face
	faceJoint.C0 = CFrame.new(0.22, 0, 0)
	faceJoint.Parent = handle
	local needleJoint = Instance.new("Weld")
	needleJoint.Part0 = handle
	needleJoint.Part1 = needle
	needleJoint.C0 = CFrame.new(0.32, 0, 0) * CFrame.Angles(0, math.rad(30), 0)
	needleJoint.Parent = handle
	return tool
end

local function removeCompasses(container: Instance?)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == CFG.compassToolName then
			child:Destroy()
		end
	end
end

-- Taruh tepat satu Star Compass di Backpack bila gear.compass == 1 (hapus duplikat dan salinan lama).
local function refreshCompass(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack or player.Parent ~= Players then
		return
	end
	removeCompasses(player:FindFirstChild("StarterGear"))
	removeCompasses(backpack)
	removeCompasses(player.Character)
	if hasCompass(DataService.getByUserId(player.UserId)) then
		buildCompass().Parent = backpack
	end
end

function StarwhaleService.countCompasses(userId: number): number
	local player = Actors.getPlayer(userId)
	if not player then
		return 0
	end
	local total = 0
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container and container:GetChildren() or {} do
			if child:IsA("Tool") and child.Name == CFG.compassToolName then
				total += 1
			end
		end
	end
	return total
end

-- ===== Star Relay (puzzle) =====

-- Membuat puzzle baru untuk pemain dan mengirimnya (tanpa solusi). Dipanggil prompt Tilly.
function StarwhaleService.requestPuzzle(userId: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	if data.starwhale.relayFixed then
		return false, "The relay is already repaired."
	end
	local now = os.clock()
	if lastRequest[userId] and now - lastRequest[userId] < 0.3 then
		return false, "Too fast."
	end
	lastRequest[userId] = now
	puzzleCounter += 1
	pending[userId] = PipePuzzle.generate(RNG.new(puzzleSeed + puzzleCounter * 7919 + userId))
	sendState(userId, true)
	return true
end

-- Memeriksa rotasi dari klien. Berhasil -> relay diperbaiki + Star Compass.
function StarwhaleService.submit(userId: number, rots): (boolean, string?)
	local data = DataService.getByUserId(userId)
	local puzzle = pending[userId]
	if not data then
		return false, "Data not loaded."
	end
	if data.starwhale.relayFixed then
		return false, "The relay is already repaired."
	end
	if not puzzle then
		notify(userId, "Talk to Tilly to get a relay puzzle first.", "error")
		return false, "No puzzle."
	end
	local applied = PipePuzzle.applyRotations(puzzle, rots)
	if not applied or not PipePuzzle.isSolved(applied) then
		notify(userId, "The relay is still broken...", "error")
		return false, "Not solved."
	end
	pending[userId] = nil
	data.starwhale.relayFixed = true
	StateReplicator.set(userId, "starwhale.relayFixed", true)
	data.gear.compass = 1
	StateReplicator.set(userId, "gear.compass", 1)
	local player = Actors.getPlayer(userId)
	if player then
		task.spawn(refreshCompass, player)
	end
	notify(userId, "Star Relay repaired! You got a Star Compass.", "success")
	sendState(userId)
	return true
end

-- ===== model paus dan pod =====

local function makePart(model: Model, base: CFrame, name: string, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Shape = props.shape or Enum.PartType.Block
	local size = props.size
	p.Size = if typeof(size) == "number" then Vector3.new(size, size, size) else size
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CFrame = base * (props.offset or CFrame.new())
	p.Parent = model
	return p
end

local function buildWhale(pos: Vector3, yaw: number): Model
	local model = Instance.new("Model")
	model.Name = "Starwhale"
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local ball = Enum.PartType.Ball
	local blue = Color3.fromRGB(110, 130, 255)
	local light = Color3.fromRGB(170, 190, 255)
	local glow = Color3.fromRGB(255, 232, 150)

	local body = makePart(model, base, "Body", {
		shape = ball,
		size = 20,
		color = blue,
		transparency = 0.35,
	})
	makePart(model, base, "Belly", {
		shape = ball,
		size = 16,
		color = light,
		transparency = 0.4,
		offset = CFrame.new(0, -3, -2),
	})
	makePart(model, base, "Head", {
		shape = ball,
		size = 16,
		color = blue,
		transparency = 0.35,
		offset = CFrame.new(0, 0, -10),
	})
	makePart(model, base, "TailMid", {
		shape = ball,
		size = 12,
		color = blue,
		transparency = 0.35,
		offset = CFrame.new(0, 1, 10),
	})
	makePart(model, base, "TailTip", {
		shape = ball,
		size = 7,
		color = blue,
		transparency = 0.35,
		offset = CFrame.new(0, 3, 17),
	})
	for side = -1, 1, 2 do
		local tag = if side < 0 then "L" else "R"
		makePart(model, base, "Fluke" .. tag, {
			size = Vector3.new(12, 0.8, 5),
			color = light,
			transparency = 0.3,
			offset = CFrame.new(side * 5, 4, 20) * CFrame.Angles(0, side * math.rad(-25), 0),
		})
		makePart(model, base, "Fin" .. tag, {
			size = Vector3.new(8, 0.6, 4),
			color = light,
			transparency = 0.3,
			offset = CFrame.new(side * 10, -3, -3) * CFrame.Angles(0, 0, side * math.rad(35)),
		})
		makePart(model, base, "Eye" .. tag, {
			shape = ball,
			size = 1.6,
			color = glow,
			material = Enum.Material.Neon,
			offset = CFrame.new(side * 5.5, 2, -16),
		})
	end
	local glowSpots = { Vector3.new(0, 10, 0), Vector3.new(0, 9, 6), Vector3.new(0, 8.5, -6) }
	for i, offset in glowSpots do
		makePart(model, base, "Glow" .. i, {
			shape = ball,
			size = 2,
			color = glow,
			material = Enum.Material.Neon,
			offset = CFrame.new(offset),
		})
	end
	local lightSource = Instance.new("PointLight")
	lightSource.Color = Color3.fromRGB(150, 170, 255)
	lightSource.Range = 40
	lightSource.Brightness = 2
	lightSource.Parent = body

	model.PrimaryPart = body
	model:PivotTo(base)
	CollectionService:AddTag(model, Tags.Starwhale)
	model.Parent = effectsFolder()
	return model
end

local function destroyPod(index: number)
	local pod = visit and visit.pods[index]
	if pod then
		visit.pods[index] = nil
		visit.podsLeft -= 1
		pod.model:Destroy()
	end
end

local function spawnPods()
	if visit.podsSpawned then
		return
	end
	visit.podsSpawned = true
	local bounds = StarwhaleMath.laneBounds(visit.pos.Z)
	for i = 1, CFG.podCount do
		local angle = (i - 1) / CFG.podCount * math.pi * 2
		local x =
			math.clamp(visit.pos.X + math.cos(angle) * CFG.podRingRadius, bounds.minX, bounds.maxX)
		local z =
			math.clamp(visit.pos.Z + math.sin(angle) * CFG.podRingRadius, bounds.minZ, bounds.maxZ)
		local model = Instance.new("Model")
		model.Name = "StardustPod"
		local base = CFrame.new(x, 0, z)
		local crystal = makePart(model, base, "Crystal", {
			size = Vector3.new(3, 5, 3),
			color = POD_COLOR,
			material = Enum.Material.Neon,
			transparency = 0.1,
			offset = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(45), math.rad(12)),
		})
		crystal.CanQuery = true
		makePart(model, base, "ShardA", {
			size = Vector3.new(1.6, 3, 1.6),
			color = POD_COLOR,
			material = Enum.Material.Neon,
			transparency = 0.2,
			offset = CFrame.new(1.8, 2, 0.8) * CFrame.Angles(0, math.rad(20), math.rad(-25)),
		})
		makePart(model, base, "ShardB", {
			size = Vector3.new(1.4, 2.4, 1.4),
			color = Color3.fromRGB(210, 170, 255),
			material = Enum.Material.Neon,
			transparency = 0.2,
			offset = CFrame.new(-1.6, 1.6, -0.9) * CFrame.Angles(0, math.rad(-30), math.rad(25)),
		})
		model.PrimaryPart = crystal
		model:SetAttribute(Attr.PodHp, CFG.podHp)
		CollectionService:AddTag(model, Tags.StardustPod)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = CFG.podPromptName
		prompt.ActionText = "Crack"
		prompt.ObjectText = "Stardust Pod"
		prompt.HoldDuration = CFG.podHoldSeconds
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = crystal
		prompt.Triggered:Connect(function(player)
			StarwhaleService.hitPod(player.UserId, i)
		end)

		model.Parent = effectsFolder()
		visit.pods[i] = { model = model, crystal = crystal, hp = CFG.podHp }
		visit.podsLeft += 1
	end
end

-- ===== kunjungan =====

-- Pemain baru dalam kunjungan (atau kunjungan baru): reset progres per-kunjungan di profil.
local function resetVisitData(userId: number)
	local data = DataService.getByUserId(userId)
	if data and visit and data.starwhale.lastVisitId ~= visit.id then
		data.starwhale.lastVisitId = visit.id
		data.starwhale.eggsFoundThisVisit = 0
		StateReplicator.set(userId, "starwhale.lastVisitId", visit.id)
		StateReplicator.set(userId, "starwhale.eggsFoundThisVisit", 0)
	end
end

function StarwhaleService.isActive(): boolean
	return visit ~= nil
end

function StarwhaleService.getWhalePosition(): Vector3?
	return visit and visit.pos
end

-- Memulai penampakan sekarang (jadwal atau admin). zone opsional (2..10).
function StarwhaleService.force(zone: number?): (boolean, string?)
	if visit then
		return false, "A Starwhale is already here."
	end
	local zoneIndex = zone
	if zoneIndex == nil or zoneIndex < CFG.zoneMin or zoneIndex > CFG.zoneMax then
		zoneIndex = rng:int(CFG.zoneMin, CFG.zoneMax)
	end
	local centerZ = (Layout.zoneZStart(zoneIndex) + Layout.zoneZEnd(zoneIndex)) / 2
	local sign = if rng:chance(0.5) then 1 else -1
	local x = sign * rng:range(CFG.laneXMin, CFG.laneXMax)
	local z = centerZ + rng:range(-CFG.zJitter, CFG.zJitter)
	local pos = Vector3.new(x, CFG.hoverY, z)
	local yaw = rng:range(0, math.pi * 2)

	local lastId = 0
	for _, entry in DataService.all() do
		lastId = math.max(lastId, entry.data.starwhale.lastVisitId or 0)
	end
	local id = math.max(Clock.now(), lastId + 1)
	visit = {
		id = id,
		zone = zoneIndex,
		pos = pos,
		yaw = yaw,
		remaining = CFG.stayingSeconds,
		progress = {},
		pods = {},
		podsLeft = 0,
		podsSpawned = false,
		model = buildWhale(pos, yaw),
	}
	pushAcc = 0
	for _, entry in DataService.all() do
		resetVisitData(entry.userId)
	end
	local zoneDef = Zones.list[zoneIndex]
	AnnouncementService.broadcast({
		AnnouncementService.text("A Starwhale has been sighted in ", WHALE_COLOR),
		{ text = zoneDef.name, color = zoneDef.accentRgb },
		AnnouncementService.text(`! Leaves in {fmtLeft(CFG.stayingSeconds)}`, WHALE_COLOR),
	})
	pushAll()
	return true
end

function StarwhaleService.endVisit()
	if not visit then
		return
	end
	local old = visit
	visit = nil
	for _, pod in old.pods do
		pod.model:Destroy()
	end
	if old.model then
		old.model:Destroy()
	end
	nextIn = CFG.intervalSeconds
	pushAll()
end

-- Detak waktu-game (Clock.every1Hz memanggil ini; uji boleh memanggil langsung).
function StarwhaleService.advance(dt: number)
	if visit then
		visit.remaining -= dt
		if visit.remaining <= 0 then
			StarwhaleService.endVisit()
			return
		end
		pushAcc += dt
		if pushAcc >= CFG.statePushSeconds then
			pushAcc = 0
			pushAll()
		end
	else
		nextIn -= dt
		if nextIn <= 0 then
			nextIn = CFG.intervalSeconds
			StarwhaleService.force()
		end
	end
end

-- Pemain berkompas yang cukup dekat (bidang XZ) menjadi "Found". Dipanggil 10 Hz.
local function checkFound()
	if not visit then
		return
	end
	for _, entry in DataService.all() do
		local userId = entry.userId
		local prog = progressOf(userId)
		if not prog.found and hasCompass(entry.data) then
			local root = Actors.getRoot(userId)
			if root then
				local dx, dz = root.Position.X - visit.pos.X, root.Position.Z - visit.pos.Z
				if math.sqrt(dx * dx + dz * dz) <= CFG.foundRadius then
					prog.found = true
					notify(userId, "STARWHALE FOUND! Find 3 odd eggs!", "success")
					sendState(userId)
				end
			end
		end
	end
end

local function bob()
	if visit and visit.model and visit.model.Parent then
		local offset = math.sin(os.clock() * 0.9) * 1.2
		visit.model:PivotTo(
			CFrame.new(visit.pos + Vector3.new(0, offset, 0)) * CFrame.Angles(0, visit.yaw, 0)
		)
	end
end

-- ===== telur aneh dan pod =====

function StarwhaleService.collect(userId: number, index: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not (visit and data) then
		return false, "no visit"
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > CFG.oddCount then
		return false, "bad index"
	end
	local prog = progressOf(userId)
	if not prog.found then
		return false, "not found yet"
	end
	if prog.done or prog.collected[index] then
		return false, "already collected"
	end
	local root = Actors.getRoot(userId)
	local pos = oddPositionsFor(userId)[index]
	if not root then
		return false, "no character"
	end
	local here = root.Position
	local dist = math.sqrt((here.X - pos[1]) ^ 2 + (here.Y - pos[2]) ^ 2 + (here.Z - pos[3]) ^ 2)
	if dist > CFG.collectServerRadius then
		return false, "too far"
	end
	prog.collected[index] = true
	prog.count += 1
	data.starwhale.lastVisitId = visit.id
	data.starwhale.eggsFoundThisVisit = prog.count
	StateReplicator.set(userId, "starwhale.eggsFoundThisVisit", prog.count)
	if prog.count >= CFG.oddCount then
		prog.done = true
		spawnPods()
		notify(userId, "Crack the crystal pods for Stardust!", "success")
	end
	sendState(userId)
	return true
end

-- Satu pukulan pod. Pukulan terakhir menghancurkan pod untuk semua dan memberi Stardust ke pemukul.
function StarwhaleService.hitPod(userId: number, podId: number): (boolean, any)
	local data = DataService.getByUserId(userId)
	if not (visit and data) then
		return false, "no visit"
	end
	local pod = visit.pods[podId]
	if not pod then
		return false, "gone"
	end
	local prog = progressOf(userId)
	if not prog.done then
		return false, "find the odd eggs first"
	end
	if prog.cracked >= CFG.podMaxPerPlayer or prog.hits >= CFG.podMaxPerPlayer * CFG.podHp then
		notify(userId, "You already cracked enough pods this visit.", "error")
		return false, "limit"
	end
	local root = Actors.getRoot(userId)
	if not root then
		return false, "no character"
	end
	if (root.Position - pod.crystal.Position).Magnitude > CFG.podReach then
		return false, "too far"
	end

	prog.hits += 1
	pod.hp -= 1
	pod.model:SetAttribute(Attr.PodHp, pod.hp)
	if pod.hp > 0 then
		pod.crystal.Transparency = 0.1 + (CFG.podHp - pod.hp) * 0.15
		return true, { hp = pod.hp, broke = false }
	end

	destroyPod(podId)
	prog.cracked += 1
	local amount = StarwhaleMath.stardustRoll(rng)
	CurrencyService.add(userId, "stardust", amount)
	notify(userId, `+{amount} Stardust`, "success")
	sendState(userId)
	return true, { hp = 0, broke = true, stardust = amount }
end

-- ===== trade =====

function StarwhaleService.trade(
	userId: number,
	offerId: string,
	targetUid: string?
): (boolean, string?)
	local function fail(message: string)
		notify(userId, message, "error")
		return false, message
	end
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	local offer = if type(offerId) == "string" then CFG.offerById[offerId] else nil
	if not offer then
		return fail("Unknown offer.")
	end
	local egg = nil
	local info = nil
	if offer.needsEgg and targetUid ~= nil then
		egg = data.eggs[targetUid]
		if egg then
			info = {
				loc = egg.loc,
				muts = egg.muts or {},
				frozen = GrowthService.isFrozen(userId, targetUid),
			}
		end
	end
	local ok, err = StarwhaleMath.validateOffer(offerId, data.stardust or 0, info, targetUid)
	if not ok then
		return fail(err or "Can't do that.")
	end
	if not CurrencyService.trySpend(userId, "stardust", offer.price) then
		return fail("Not enough Stardust.")
	end

	if offer.needsEgg then
		egg.muts = MutationLogic.add(egg.muts or {}, "Orbital")
		StateReplicator.set(userId, `eggs.{targetUid}.muts`, egg.muts)
		GrowthService.ensureModel(userId, targetUid)
		notify(userId, "Orbital mutation applied!", "success")
	else
		local field = offer.boostField
		local untilAt = math.max(data.boosts[field] or 0, Clock.now() + offer.boostSeconds)
		data.boosts[field] = untilAt
		StateReplicator.set(userId, `boosts.{field}`, untilAt)
		notify(userId, `{offer.name} activated!`, "success")
	end
	sendState(userId)
	return true
end

-- ===== kios Tilly =====

local function buildStall()
	local parent = workspace:FindFirstChild(Names.Map) or workspace
	local model = Instance.new("Model")
	model.Name = "SignalTowerStall"
	local origin = Vector3.new(CFG.stall.x, 0, CFG.stall.z)

	local function block(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material,
		shape
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = origin + offset
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local steel = Color3.fromRGB(88, 100, 140)
	block("TowerBase", Vector3.new(14, 2, 14), Vector3.new(0, 1, 0), Color3.fromRGB(70, 76, 100))
	block("Tower", Vector3.new(7, 30, 7), Vector3.new(0, 17, 0), steel)
	block("Platform", Vector3.new(11, 1, 11), Vector3.new(0, 32.5, 0), Color3.fromRGB(60, 66, 90))
	local dish = block(
		"Dish",
		Vector3.new(1.5, 12, 12),
		Vector3.new(0, 36, 0),
		Color3.fromRGB(210, 220, 255),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	dish.CFrame = CFrame.new(origin + Vector3.new(0, 36, 0)) * CFrame.Angles(0, 0, math.rad(55))
	block(
		"DishSpike",
		Vector3.new(0.5, 0.5, 6),
		Vector3.new(0, 38.5, 0),
		Color3.fromRGB(255, 232, 150),
		Enum.Material.Neon
	)
	block(
		"Beacon",
		Vector3.new(2, 2, 2),
		Vector3.new(0, 40.5, 0),
		Color3.fromRGB(150, 190, 255),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)

	-- Tilly: figur kecil dari Part di depan menara.
	local npcOffset = Vector3.new(0, 0, 9)
	local skin = Color3.fromRGB(240, 200, 160)
	block(
		"TillyLegs",
		Vector3.new(2, 2.4, 1.2),
		npcOffset + Vector3.new(0, 1.6, 0),
		Color3.fromRGB(60, 50, 110)
	)
	local torso = block(
		"TillyTorso",
		Vector3.new(2.4, 2.8, 1.4),
		npcOffset + Vector3.new(0, 4.2, 0),
		Color3.fromRGB(110, 90, 200)
	)
	block("TillyArmL", Vector3.new(0.7, 2.4, 0.7), npcOffset + Vector3.new(-1.6, 4.3, 0), skin)
	block("TillyArmR", Vector3.new(0.7, 2.4, 0.7), npcOffset + Vector3.new(1.6, 4.3, 0), skin)
	local head = block(
		"TillyHead",
		Vector3.new(1.8, 1.8, 1.8),
		npcOffset + Vector3.new(0, 6.5, 0),
		skin,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	block(
		"TillyHat",
		Vector3.new(2.4, 1.2, 2.4),
		npcOffset + Vector3.new(0, 7.7, 0),
		Color3.fromRGB(50, 40, 110)
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(280, 60)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 200
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Astronomer Tilly"
	label.TextColor3 = Color3.fromRGB(190, 210, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 30, 70)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = CFG.promptName
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Astronomer Tilly"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso
	prompt.Triggered:Connect(function(player)
		StarwhaleService.requestPuzzle(player.UserId)
	end)

	model.Parent = parent
end

-- ===== lifecycle =====

local function onJoin(ctx)
	local userId = ctx.userId
	resetVisitData(userId)
	local player = ctx.player
	if not player then
		return
	end
	if compassMaids[userId] then
		compassMaids[userId]:Clean()
	end
	local maid = Maid.new()
	compassMaids[userId] = maid
	maid:Give(player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Backpack dibuat ulang saat respawn
		if player.Character == character then
			refreshCompass(player)
		end
	end))
	task.spawn(refreshCompass, player)
end

local function onLeaving(ctx)
	local userId = ctx.userId
	pending[userId] = nil
	lastSent[userId] = nil
	lastRequest[userId] = nil
	local maid = compassMaids[userId]
	if maid then
		maid:Clean()
		compassMaids[userId] = nil
	end
	if ctx.player then
		removeCompasses(ctx.player:FindFirstChildOfClass("Backpack"))
		removeCompasses(ctx.player.Character)
	end
end

function StarwhaleService.Init()
	buildStall()

	PlayerLifecycle.onJoin("StarwhaleService", 100, onJoin)
	PlayerLifecycle.onLeaving("StarwhaleService", 100, onLeaving)

	InvariantChecker.register("Starwhale", function(entry)
		local out = {}
		local sw = entry.data.starwhale
		if type(sw) ~= "table" or type(sw.relayFixed) ~= "boolean" then
			table.insert(out, "starwhale.relayFixed bukan boolean")
			return out
		end
		local found = sw.eggsFoundThisVisit
		if type(found) ~= "number" or found < 0 or found > CFG.oddCount then
			table.insert(out, `eggsFoundThisVisit di luar 0..{CFG.oddCount}: {tostring(found)}`)
		end
		if entry.data.gear.compass == 1 and not sw.relayFixed then
			table.insert(out, "punya compass tanpa relay diperbaiki")
		end
		return out
	end)
	InvariantChecker.registerWorld("Starwhale", function()
		local out = {}
		local models = #CollectionService:GetTagged(Tags.Starwhale)
		local pods = #CollectionService:GetTagged(Tags.StardustPod)
		if visit == nil and (models > 0 or pods > 0) then
			table.insert(out, `paus/pod tersisa tanpa kunjungan: {models}/{pods}`)
		end
		if visit and models ~= 1 then
			table.insert(out, `model paus harus 1, ada {models}`)
		end
		if pods > CFG.podCount then
			table.insert(out, `pod melebihi batas: {pods}`)
		end
		return out
	end)

	TestBridge.register("starwhale.state", function()
		if not visit then
			return {
				active = false,
				nextIn = nextIn,
				models = #CollectionService:GetTagged(Tags.Starwhale),
				pods = #CollectionService:GetTagged(Tags.StardustPod),
			}
		end
		return {
			active = true,
			id = visit.id,
			zone = visit.zone,
			x = visit.pos.X,
			y = visit.pos.Y,
			z = visit.pos.Z,
			remaining = visit.remaining,
			podsLeft = visit.podsLeft,
			podsSpawned = visit.podsSpawned,
			hasModel = visit.model ~= nil and visit.model.Parent ~= nil,
			models = #CollectionService:GetTagged(Tags.Starwhale),
			pods = #CollectionService:GetTagged(Tags.StardustPod),
		}
	end)
	TestBridge.register("starwhale.force", function(zone)
		local ok, err = StarwhaleService.force(zone)
		return { ok = ok, err = err }
	end)
	TestBridge.register("starwhale.end", function()
		StarwhaleService.endVisit()
		return true
	end)
	TestBridge.register("starwhale.advance", function(dt)
		StarwhaleService.advance(dt)
		return true
	end)
	TestBridge.register("starwhale.info", function(userId)
		local prog = visit and visit.progress[userId]
		local data = DataService.getByUserId(userId)
		return {
			found = prog ~= nil and prog.found,
			count = prog and prog.count or 0,
			done = prog ~= nil and prog.done,
			cracked = prog and prog.cracked or 0,
			hits = prog and prog.hits or 0,
			hasPending = pending[userId] ~= nil,
			compassTools = StarwhaleService.countCompasses(userId),
			relayFixed = data ~= nil and data.starwhale.relayFixed,
		}
	end)
	TestBridge.register("starwhale.podPos", function(index)
		local pod = visit and visit.pods[index]
		if not pod then
			return nil
		end
		local p = pod.crystal.Position
		return { p.X, p.Y, p.Z }
	end)
	TestBridge.register("starwhale.seed", function(seed)
		puzzleSeed = seed
		rng:reseed(seed)
		return true
	end)
	-- HANYA uji: solusi rotasi puzzle yang menunggu.
	TestBridge.register("starwhale.puzzle", function(userId)
		local puzzle = pending[userId]
		return puzzle and puzzle.solution
	end)
	TestBridge.register("starwhale.lastPayload", function(userId)
		return lastSent[userId]
	end)

	AdminService.register("starwhale", function(player, args)
		local sub = args[1]
		if sub == "end" then
			StarwhaleService.endVisit()
			return "Starwhale pergi"
		end
		if sub == "fix" then
			local data = DataService.getByUserId(player.UserId)
			if not data then
				return "Data belum dimuat"
			end
			data.starwhale.relayFixed = true
			StateReplicator.set(player.UserId, "starwhale.relayFixed", true)
			data.gear.compass = 1
			StateReplicator.set(player.UserId, "gear.compass", 1)
			task.spawn(refreshCompass, player)
			sendState(player.UserId)
			return "Relay diperbaiki + Star Compass"
		end
		local ok, err = StarwhaleService.force(tonumber(sub))
		return if ok then "Starwhale muncul" else tostring(err)
	end)
end

function StarwhaleService.Start()
	Net.on("SubmitRelay", Check.args(Check.intGrid(5, 5, 0, 3)), function(player, rots)
		StarwhaleService.submit(player.UserId, rots)
	end)
	Net.on("CollectOddEgg", Check.args(Check.int(1, 3)), function(player, index)
		StarwhaleService.collect(player.UserId, index)
	end)
	Net.on(
		"TradeStardust",
		Check.args(Check.enum(CFG.offerIds), Check.optional(Check.uid)),
		function(player, offerId, targetUid)
			StarwhaleService.trade(player.UserId, offerId, targetUid)
		end
	)
	Net.on("ClientReady", Check.args(), function(player)
		sendState(player.UserId)
	end)

	Clock.every1Hz(function(dt)
		StarwhaleService.advance(dt)
	end)
	Clock.every10Hz(function()
		bob()
		checkFound()
	end)
end

return StarwhaleService
