--!nonstrict
-- GrowthService: pertumbuhan telur yang sudah ditempatkan (loc == "placed") dan model telur di Coop.
-- progress/growTotal dalam detik waktu-game; progress += dt * multiplier (malam x30, boost 2x, dst.).
-- Hatch dimintakan lewat sinyal onHatchRequested (HatchService yang menanganinya; menghindari require berputar).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Progression = require(Shared.Config.Progression)
local Zones = require(Shared.Config.Zones)
local PetMath = require(Shared.Logic.PetMath)
local ModelFactory = require(Shared.ModelFactory)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Clock = require(Systems.Clock)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags

local GrowthService = {}
GrowthService.onHatchRequested = Signal.new() -- (player, eggUid)

local models = {} -- [userId] = { [eggUid] = Model }
local globalMultipliers = {} -- [name] = number (mis. night = 30)
local providers = {} -- [name] = function(userId) -> number (pengali)

function GrowthService.setGlobalMultiplier(name: string, value: number?)
	globalMultipliers[name] = value
end

function GrowthService.addMultiplierProvider(name: string, fn: (number) -> number)
	providers[name] = fn
end

function GrowthService.multiplier(userId: number): number
	local m = 1
	for _, v in globalMultipliers do
		m *= v
	end
	local data = DataService.getByUserId(userId)
	if data and (data.boosts.growth2xUntil or 0) > Clock.now() then
		m *= 2
	end
	for _, fn in providers do
		m *= fn(userId)
	end
	return m
end

function GrowthService.getModel(userId: number, uid: string): Model?
	return models[userId] and models[userId][uid]
end

local function isReady(egg): boolean
	return egg.progress >= egg.growTotal
end

-- Sinkronkan atribut/skala/prompt model dengan data telur.
local function updateModel(model: Model, egg)
	local fraction = if egg.growTotal > 0 then math.clamp(egg.progress / egg.growTotal, 0, 1) else 1
	local ready = isReady(egg)
	model:SetAttribute(Attr.Progress, fraction)
	model:SetAttribute(Attr.Ready, ready)
	model:SetAttribute(Attr.GrowRemaining, math.max(egg.growTotal - egg.progress, 0))

	local scale = 0.6 + 0.4 * fraction
	ModelFactory.setEggScale(model, scale)
	local d = ModelFactory.eggDiameter(egg.kg)
	local pos = model:GetPivot().Position
	model:PivotTo(CFrame.new(pos.X, 0.05 + d * 0.625 * scale, pos.Z))

	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild(Names.HatchPrompt)
	if prompt then
		prompt.Enabled = ready
	end
end

function GrowthService.removeModel(userId: number, uid: string)
	local bucket = models[userId]
	if bucket and bucket[uid] then
		bucket[uid]:Destroy()
		bucket[uid] = nil
	end
end

-- Membuat (atau membuat ulang) model telur placed di Coop pemilik.
function GrowthService.ensureModel(userId: number, uid: string)
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	local egg = data and data.eggs[uid]
	if not (egg and plot and egg.loc == "placed" and egg.pos) then
		return
	end
	GrowthService.removeModel(userId, uid)

	local creature = Creatures.get(egg.id)
	local zone = Zones.get(creature.zone)
	local accent = Color3.fromRGB(zone.accentRgb[1], zone.accentRgb[2], zone.accentRgb[3])
	local model = ModelFactory.makeEgg(creature, egg.kg, accent)
	model.Name = "PlacedEgg_" .. uid
	model:SetAttribute(Attr.EggUid, uid)
	model:SetAttribute(Attr.SpeciesId, egg.id)
	model:SetAttribute(Attr.Rarity, creature.rarity)
	model:SetAttribute(Attr.Kg, egg.kg)
	model:SetAttribute(Attr.Income, PetMath.eggProjectedIncome(egg.id, egg.kg, egg.muts))
	model:SetAttribute(Attr.ZoneIndex, creature.zone)
	model:SetAttribute(Attr.GrowTotal, egg.growTotal)
	CollectionService:AddTag(model, Tags.PlacedEgg)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Names.HatchPrompt
	prompt.ActionText = "Hatch!"
	prompt.ObjectText = creature.name .. " Egg"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = Eggs.hatchMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		GrowthService.onHatchRequested:Fire(player, uid)
	end)

	local world = PlotService.localToWorld(plot, egg.pos.x, egg.pos.z)
	model:PivotTo(CFrame.new(world.X, 0.05, world.Z))
	updateModel(model, egg)
	model.Parent = plot:FindFirstChild(Names.PlotEggs)

	models[userId] = models[userId] or {}
	models[userId][uid] = model
end

local function tick(dt: number)
	for _, entry in DataService.all() do
		local userId, data = entry.userId, entry.data
		local mult
		for uid, egg in data.eggs do
			if egg.loc == "placed" and not isReady(egg) then
				mult = mult or GrowthService.multiplier(userId)
				egg.progress = math.min(egg.growTotal, egg.progress + dt * mult)
				local model = GrowthService.getModel(userId, uid)
				if model then
					updateModel(model, egg)
				end
				StateReplicator.set(userId, `eggs.{uid}.progress`, egg.progress)
			end
		end
	end
end

function GrowthService.Init()
	PlayerLifecycle.onJoin("GrowthService", 50, function(ctx)
		for uid, egg in ctx.data.eggs do
			if egg.loc == "placed" then
				GrowthService.ensureModel(ctx.userId, uid)
			end
		end
	end)
	PlayerLifecycle.onLeaving("GrowthService", 50, function(ctx)
		local bucket = models[ctx.userId]
		if bucket then
			for _, model in bucket do
				model:Destroy()
			end
			models[ctx.userId] = nil
		end
	end)

	InvariantChecker.register("Growth", function(entry)
		local out = {}
		local placed = 0
		for uid, egg in entry.data.eggs do
			if egg.loc ~= "placed" and egg.loc ~= "pocket" then
				table.insert(out, `egg {uid} loc tidak valid: {tostring(egg.loc)}`)
			end
			if egg.loc == "placed" then
				placed += 1
				if not egg.pos then
					table.insert(out, `egg {uid} placed tanpa pos`)
				end
				if
					not GrowthService.getModel(entry.userId, uid)
					and PlotService.getPlot(entry.userId)
				then
					table.insert(out, `egg {uid} placed tanpa model`)
				end
			end
			if egg.progress < 0 or egg.progress > egg.growTotal + 1e-6 then
				table.insert(out, `egg {uid} progress di luar rentang`)
			end
		end
		local slots = Progression.eggSlotsFor(entry.data.penLevel, entry.data.plotExpansion)
		if placed > slots then
			table.insert(out, `placed {placed} > slot {slots}`)
		end
		return out
	end)

	TestBridge.register("growth.models", function(userId)
		local count = 0
		for _ in models[userId] or {} do
			count += 1
		end
		return count
	end)
	-- Uji: majukan progres sebuah telur (detik waktu-game) tanpa menunggu.
	TestBridge.register("growth.advance", function(userId, uid, seconds)
		local data = DataService.getByUserId(userId)
		local egg = data and data.eggs[uid]
		if not egg then
			return false
		end
		egg.progress = math.min(egg.growTotal, egg.progress + seconds)
		local model = GrowthService.getModel(userId, uid)
		if model then
			updateModel(model, egg)
		end
		StateReplicator.set(userId, `eggs.{uid}.progress`, egg.progress)
		return egg.progress
	end)
end

function GrowthService.Start()
	Clock.every1Hz(tick)
end

return GrowthService
