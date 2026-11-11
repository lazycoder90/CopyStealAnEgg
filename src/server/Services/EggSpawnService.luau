--!nonstrict
-- EggSpawnService: sarang (nest) dan telur dunia.
-- Nest state machine: Empty -> Occupied -> Carried -> (Occupied via return | Empty via destroy) ; Dropped = telur jatuh.
-- Egg Reset (resetAll) hanya me-roll ulang nest Empty/Occupied; telur Carried/Dropped tidak disentuh.
-- Telur jatuh/kembali memakai waktu NYATA (os.clock), bukan timeScale.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Zones = require(Shared.Config.Zones)
local EggRoll = require(Shared.Logic.EggRoll)
local NestLayout = require(Shared.Logic.NestLayout)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)
local ModelFactory = require(Shared.ModelFactory)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local InvariantChecker = require(Systems.InvariantChecker)
local TestBridge = require(Systems.TestBridge)

local Names, Attr, Tags, NestState = Types.Names, Types.Attr, Types.Tags, Types.NestState

local EggSpawnService = {}
EggSpawnService.onGrabRequested = Signal.new() -- (player, eggUid)

local nests = {} -- [nestId] = { id, zone, x, z, grand, state, entity, part, respawnAt }
local entities = {} -- [uid] = entity
local container: Folder
local rng = RNG.new(os.time())
local luck = 1

local NEST_Y = 0.3

local function newUid(): string
	local guid = HttpService:GenerateGUID(false)
	return string.sub((string.gsub(guid, "-", "")), 1, 16)
end

function EggSpawnService.setSeed(seed: number)
	rng:reseed(seed)
end

function EggSpawnService.setLuck(value: number)
	luck = value
end

local function setNestState(nest, state: string)
	nest.state = state
	nest.part:SetAttribute(Attr.NestState, state)
end

local function eggCenterY(entity): number
	return 0.6 + ModelFactory.eggDiameter(entity.kg) * 0.625
end

local function decorate(entity, creature)
	local model = entity.model
	model.Name = "Egg_" .. entity.uid
	model:SetAttribute(Attr.EggUid, entity.uid)
	model:SetAttribute(Attr.SpeciesId, entity.speciesId)
	model:SetAttribute(Attr.Rarity, entity.rarity)
	model:SetAttribute(Attr.Kg, entity.kg)
	model:SetAttribute(
		Attr.Income,
		PetMath.eggProjectedIncome(entity.speciesId, entity.kg, entity.muts)
	)
	model:SetAttribute(Attr.ZoneIndex, entity.zone)
	model:SetAttribute(Attr.GrowTotal, entity.growTotal)
	model:SetAttribute(Attr.IsGrand, entity.grand)
	CollectionService:AddTag(model, Tags.WorldEgg)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Names.GrabPrompt
	prompt.ActionText = "Grab"
	prompt.ObjectText = creature.name .. " Egg"
	prompt.HoldDuration = Eggs.grabHoldDuration
	prompt.MaxActivationDistance = Eggs.grabMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		EggSpawnService.onGrabRequested:Fire(player, entity.uid)
	end)
end

local function spawnInto(nest)
	local roll = EggRoll.rollEgg(rng, nest.zone, nest.grand, luck)
	local creature = Creatures.get(roll.speciesId)
	local zone = Zones.get(nest.zone)
	local accent = Color3.fromRGB(zone.accentRgb[1], zone.accentRgb[2], zone.accentRgb[3])

	local entity = {
		uid = newUid(),
		speciesId = roll.speciesId,
		kg = roll.kg,
		muts = {},
		rarity = creature.rarity,
		zone = nest.zone,
		nestId = nest.id,
		growTotal = roll.growTotal,
		grand = nest.grand,
		state = NestState.Occupied,
		model = ModelFactory.makeEgg(creature, roll.kg, accent),
	}
	decorate(entity, creature)
	entity.model:PivotTo(CFrame.new(nest.x, eggCenterY(entity), nest.z))
	entity.model.Parent = container

	entities[entity.uid] = entity
	nest.entity = entity
	nest.respawnAt = nil
	setNestState(nest, NestState.Occupied)

	GameEvents.EggSpawned:Fire({
		zone = nest.zone,
		speciesId = roll.speciesId,
		rarity = creature.rarity,
		grand = nest.grand,
		nestId = nest.id,
	})
	return entity
end

local function createNests()
	local folder = Instance.new("Folder")
	folder.Name = "Nests"
	folder.Parent = workspace:WaitForChild(Names.Map)

	for _, zone in Zones.list do
		for _, spec in NestLayout.forZone(zone.index) do
			local d = if spec.grand then 12 else 6
			local part = Instance.new("Part")
			part.Name = "Nest_" .. spec.id
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.6, d, d)
			part.CFrame = CFrame.new(spec.x, NEST_Y, spec.z) * CFrame.Angles(0, 0, math.rad(90))
			part.Color = Color3.fromRGB(122, 86, 52)
			part.Material = Enum.Material.Wood
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part:SetAttribute(Attr.NestId, spec.id)
			part:SetAttribute(Attr.ZoneIndex, spec.zone)
			part:SetAttribute(Attr.IsGrand, spec.grand)
			part:SetAttribute(Attr.NestState, NestState.Empty)
			CollectionService:AddTag(part, Tags.Nest)
			part.Parent = folder
			nests[spec.id] = {
				id = spec.id,
				zone = spec.zone,
				x = spec.x,
				z = spec.z,
				grand = spec.grand,
				state = NestState.Empty,
				entity = nil,
				part = part,
				respawnAt = nil,
			}
		end
	end
end

function EggSpawnService.getEntity(uid: string)
	return entities[uid]
end

function EggSpawnService.getNest(nestId: string)
	return nests[nestId]
end

function EggSpawnService.entityPosition(entity): Vector3
	return entity.model:GetPivot().Position
end

-- Mengambil telur untuk dibawa. Hanya state Occupied/Dropped. Model TIDAK dipindah (CarryService yang mengurus).
function EggSpawnService.takeEgg(uid: string)
	local entity = entities[uid]
	if not entity or (entity.state ~= NestState.Occupied and entity.state ~= NestState.Dropped) then
		return nil
	end
	entity.state = NestState.Carried
	entity.returnAt = nil
	local nest = nests[entity.nestId]
	if nest then
		setNestState(nest, NestState.Carried)
	end
	local prompt = entity.model.PrimaryPart:FindFirstChild(Names.GrabPrompt)
	if prompt then
		prompt.Enabled = false
	end
	return entity
end

-- Meletakkan telur yang dibawa/di-drop di tanah (groundPos = titik di permukaan tanah).
function EggSpawnService.dropEggAt(entity, groundPos: Vector3)
	if not entities[entity.uid] then
		return
	end
	entity.state = NestState.Dropped
	entity.returnAt = os.clock() + Eggs.worldEggReturnTime
	local nest = nests[entity.nestId]
	if nest then
		setNestState(nest, NestState.Dropped)
	end
	local model = entity.model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.Massless = false
		end
	end
	model.Parent = container
	model:PivotTo(CFrame.new(groundPos + Vector3.new(0, eggCenterY(entity) - 0.6, 0)))
	local prompt = model.PrimaryPart:FindFirstChild(Names.GrabPrompt)
	if prompt then
		prompt.Enabled = true
	end
end

-- Menghapus entity dari dunia. Nest-nya menjadi Empty (respawn kecil setelah jeda).
function EggSpawnService.destroyEntity(entity)
	entities[entity.uid] = nil
	if entity.model then
		entity.model:Destroy()
		entity.model = nil
	end
	local nest = nests[entity.nestId]
	if nest and nest.entity == entity then
		nest.entity = nil
		setNestState(nest, NestState.Empty)
		if not nest.grand then
			nest.respawnAt = os.clock() + Eggs.smallNestRespawn
		end
	end
	entity.state = "Destroyed"
end

-- Mengembalikan telur ke nest asalnya (Occupied). Jika nest tidak lagi miliknya, telur dihancurkan.
function EggSpawnService.returnToNest(entity)
	local nest = nests[entity.nestId]
	if not (nest and nest.entity == entity) then
		EggSpawnService.destroyEntity(entity)
		return
	end
	local model = entity.model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = container
	model:PivotTo(CFrame.new(nest.x, eggCenterY(entity), nest.z))
	entity.state = NestState.Occupied
	entity.returnAt = nil
	setNestState(nest, NestState.Occupied)
	local prompt = model.PrimaryPart:FindFirstChild(Names.GrabPrompt)
	if prompt then
		prompt.Enabled = true
	end
end

-- Egg Reset global: me-roll ulang nest Empty/Occupied. Mengembalikan jumlah nest yang di-roll.
function EggSpawnService.resetAll(): number
	local count = 0
	for _, nest in nests do
		if nest.state == NestState.Occupied or nest.state == NestState.Empty then
			if nest.entity then
				EggSpawnService.destroyEntity(nest.entity)
			end
			spawnInto(nest)
			count += 1
		end
	end
	return count
end

function EggSpawnService.stats()
	local counts = { Empty = 0, Occupied = 0, Carried = 0, Dropped = 0, entities = 0 }
	for _, nest in nests do
		counts[nest.state] += 1
	end
	for _ in entities do
		counts.entities += 1
	end
	return counts
end

local function tick()
	local now = os.clock()
	for _, entity in entities do
		if entity.state == NestState.Dropped and entity.returnAt and now >= entity.returnAt then
			EggSpawnService.returnToNest(entity)
		end
	end
	for _, nest in nests do
		if nest.state == NestState.Empty and nest.respawnAt and now >= nest.respawnAt then
			spawnInto(nest)
		end
	end
end

function EggSpawnService.Init()
	container = workspace:WaitForChild(Names.WorldEggs)
	createNests()

	InvariantChecker.registerWorld("EggSpawn", function()
		local out = {}
		for _, nest in nests do
			local e = nest.entity
			if nest.state == NestState.Empty and e then
				table.insert(out, `nest {nest.id} Empty tapi punya entity`)
			elseif nest.state ~= NestState.Empty and not e then
				table.insert(out, `nest {nest.id} {nest.state} tanpa entity`)
			elseif e and e.state ~= nest.state then
				table.insert(out, `nest {nest.id} {nest.state} != entity {e.state}`)
			elseif e and nest.state == NestState.Occupied and e.model.Parent ~= container then
				table.insert(out, `egg {e.uid} Occupied tapi model tidak di WorldEggs`)
			end
		end
		return out
	end)

	TestBridge.register("eggs.stats", EggSpawnService.stats)
	TestBridge.register("eggs.reset", EggSpawnService.resetAll)
	TestBridge.register("eggs.seed", function(seed)
		EggSpawnService.setSeed(seed)
		return true
	end)
	-- Telur Occupied terdekat dari pemain (untuk uji): { uid, speciesId, zone, pos }
	TestBridge.register("eggs.nearest", function(userId, zone)
		local root = require(Systems.Actors).getRoot(userId)
		if not root then
			return nil
		end
		local best, bestDist
		for _, entity in entities do
			if entity.state == NestState.Occupied and (zone == nil or entity.zone == zone) then
				local d = (EggSpawnService.entityPosition(entity) - root.Position).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = entity, d
				end
			end
		end
		if not best then
			return nil
		end
		local p = EggSpawnService.entityPosition(best)
		return {
			uid = best.uid,
			speciesId = best.speciesId,
			zone = best.zone,
			rarity = best.rarity,
			grand = best.grand,
			pos = { p.X, p.Y, p.Z },
			distance = bestDist,
		}
	end)
end

function EggSpawnService.Start()
	for _, nest in nests do
		spawnInto(nest)
	end
	Clock.every1Hz(tick)
end

return EggSpawnService
