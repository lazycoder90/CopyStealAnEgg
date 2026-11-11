--!nonstrict
-- Bot uji = pemain virtual (userId negatif, mis. -1..-7) dengan rig blok sederhana di Workspace.Bots.
-- Dipakai skenario uji PvP (Steal/Defense). Bot punya profil (DataService.registerVirtual), Coop sendiri
-- (PlotService lewat hook onJoin) dan karakter yang terdaftar di Actors. Tidak ada klien: tidak ada replikasi.
-- Hook TestBridge: bot.spawn(id), bot.remove(id), bot.giveEgg(id, speciesId, kg?, ready?),
-- bot.moveTo(id, x, y, z), bot.removeAll().

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Layout = require(Shared.Config.Layout)
local Progression = require(Shared.Config.Progression)
local ModelFactory = require(Shared.ModelFactory)
local Types = require(Shared.Types)

local Actors = require(script.Parent.Actors)
local Clock = require(script.Parent.Clock)
local TestBridge = require(script.Parent.TestBridge)

local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local GrowthService = require(Services.GrowthService)
local PlotService = require(Services.PlotService)

local Names = Types.Names

local Bots = {}

local GROW_TOTAL = 600 -- detik waktu-game untuk telur bot
local GRID_STEP = 7 -- > Eggs.placeMinSpacing

local spawned = {} -- [userId] = Model

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

local function folder(): Folder
	local f = workspace:FindFirstChild(Names.Bots)
	if not f then
		f = Instance.new("Folder")
		f.Name = Names.Bots
		f.Parent = workspace
	end
	return f
end

local function part(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = CFrame.new(offset)
	p.Parent = model
	return p
end

-- Rig minimal: HumanoidRootPart (badan), Head, dua kaki. Semua Anchored; digerakkan lewat PivotTo.
local function buildRig(userId: number): Model
	local model = Instance.new("Model")
	model.Name = `Bot{math.abs(userId)}`
	local color = ModelFactory.speciesColor(`bot{userId}`, 0.6, 0.9)
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, color)
	part(
		model,
		"Head",
		Vector3.new(1.4, 1.2, 1.4),
		Vector3.new(0, 1.6, 0),
		Color3.fromRGB(255, 220, 170)
	)
	part(model, "LeftLeg", Vector3.new(0.9, 2, 1), Vector3.new(-0.5, -2, 0), color)
	part(model, "RightLeg", Vector3.new(0.9, 2, 1), Vector3.new(0.5, -2, 0), color)
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 16
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	return model
end

function Bots.get(userId: number): Model?
	return spawned[userId]
end

function Bots.moveTo(userId: number, x: number, y: number, z: number): boolean
	local model = spawned[userId]
	if not model then
		return false
	end
	model:PivotTo(CFrame.new(x, y, z))
	return true
end

-- Membuat bot dan Coop-nya. Mengembalikan Model (atau yang sudah ada).
function Bots.spawn(userId: number): Model
	assert(userId < 0, "id bot harus negatif")
	if spawned[userId] then
		return spawned[userId]
	end
	local model = buildRig(userId)
	model.Parent = folder()
	spawned[userId] = model
	Actors.registerBot(userId, model)
	DataService.registerVirtual(userId, nil, model) -- hook onJoin: PlotService memberi Coop

	local plot = PlotService.getPlot(userId)
	local spawnPoint = plot and plot:FindFirstChild(Names.PlotSpawn)
	if spawnPoint then
		model:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 4, 0)))
	end
	return model
end

function Bots.remove(userId: number)
	local model = spawned[userId]
	if not model then
		return
	end
	spawned[userId] = nil
	DataService.unregisterVirtual(userId) -- hook onLeaving berjalan selagi aktor masih terdaftar
	Actors.unregisterBot(userId)
	model:Destroy()
end

function Bots.removeAll()
	local ids = {}
	for userId in spawned do
		table.insert(ids, userId)
	end
	for _, userId in ids do
		Bots.remove(userId)
	end
	local f = workspace:FindFirstChild(Names.Bots)
	if f then
		f:ClearAllChildren()
	end
end

-- Titik grid pertama yang valid di Coop bot (aturan sama dengan PlacementService), atau nil.
local function freeSpot(data)
	local half = math.floor((Layout.plotSize / 2 - Eggs.placeInset) / GRID_STEP) * GRID_STEP
	for gz = -half, half, GRID_STEP do
		for gx = -half, half, GRID_STEP do
			if
				PlotService.isInsideLocal(gx, gz, Eggs.placeInset)
				and not PlotService.isReservedLocal(gx, gz)
			then
				local free = true
				for _, egg in data.eggs do
					if egg.loc == "placed" and egg.pos then
						local dx, dz = gx - egg.pos.x, gz - egg.pos.z
						if dx * dx + dz * dz < Eggs.placeMinSpacing * Eggs.placeMinSpacing then
							free = false
							break
						end
					end
				end
				if free then
					return gx, gz
				end
			end
		end
	end
	return nil
end

-- Menaruh telur placed di Coop bot. ready=true: progres penuh (siap menetas). Mengembalikan uid atau nil, galat.
function Bots.giveEgg(userId: number, speciesId: string, kg: number?, ready: boolean?)
	local data = DataService.getByUserId(userId)
	if not (data and PlotService.getPlot(userId)) then
		return nil, "bot tidak ada"
	end
	local placed = 0
	for _, egg in data.eggs do
		if egg.loc == "placed" then
			placed += 1
		end
	end
	if placed >= Progression.eggSlotsFor(data.penLevel, data.plotExpansion) then
		return nil, "Coop bot penuh"
	end
	local gx, gz = freeSpot(data)
	if not gx then
		return nil, "tidak ada tempat kosong"
	end
	local creature = Creatures.get(speciesId)
	local uid = newUid()
	data.eggs[uid] = {
		id = speciesId,
		kg = kg or creature.baseKg,
		muts = {},
		growTotal = GROW_TOTAL,
		progress = if ready then GROW_TOTAL else GROW_TOTAL * 0.2,
		loc = "placed",
		pos = { x = gx, z = gz },
		t = Clock.now(),
	}
	GrowthService.ensureModel(userId, uid)
	return uid
end

function Bots.Init()
	TestBridge.register("bot.spawn", function(userId)
		Bots.spawn(userId)
		return true
	end)
	TestBridge.register("bot.remove", function(userId)
		Bots.remove(userId)
		return true
	end)
	TestBridge.register("bot.giveEgg", function(userId, speciesId, kg, ready)
		local uid, err = Bots.giveEgg(userId, speciesId, kg, ready)
		return { uid = uid, err = err }
	end)
	TestBridge.register("bot.moveTo", function(userId, x, y, z)
		return Bots.moveTo(userId, x, y, z)
	end)
	TestBridge.register("bot.removeAll", function()
		Bots.removeAll()
		return true
	end)
end

return Bots
