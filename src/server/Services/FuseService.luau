--!nonstrict
-- FuseService: kios "FUSE MACHINE" di hub. 3 pet sejenis (tidak aktif, tidak terkunci) dilebur menjadi 1 pet
-- lewat FuseLogic.fuse (docs/PLAN.md §4.13). Seluruh perubahan state atomik tanpa yield.
-- Klien membuka panel lewat ProximityPromptService (nama prompt dari CollectionConfig), tanpa remote.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Creatures = require(Shared.Config.Creatures)
local FuseLogic = require(Shared.Logic.FuseLogic)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local PetService = require(script.Parent.PetService)
local StateReplicator = require(script.Parent.StateReplicator)

local FuseService = {}

local rng = RNG.new(os.time() + 31)

function FuseService.setSeed(seed: number)
	rng:reseed(seed)
end

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

-- uids: daftar 3 uid pet. Mengembalikan true + payload FuseResult, atau false + pesan galat.
function FuseService.fuse(userId: number, uids): (boolean, any)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	if type(uids) ~= "table" or #uids ~= CollectionConfig.fuse.petCount then
		return false, "Pick exactly 3 creatures."
	end

	local list, seen = {}, {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return false, "Pick 3 different creatures."
		end
		seen[uid] = true
		local pet = data.pets[uid]
		if not pet then
			return false, "Creature not found."
		end
		if pet.eq then
			return false, "Unequip the creatures first."
		end
		if pet.lock then
			return false, "Unlock the creatures first."
		end
		table.insert(list, { id = pet.id, kg = pet.kg, muts = pet.muts or {} })
	end

	local canFuse, reason = FuseLogic.canFuse(list)
	if not canFuse then
		return false, reason
	end

	local cost = FuseLogic.cost(list)
	if not CurrencyService.trySpend(userId, "cash", cost) then
		return false, "Not enough cash."
	end

	-- Dari sini tanpa kegagalan: hapus 3 pet, tambah 1 pet hasil.
	local result = FuseLogic.fuse(rng, list)
	for _, uid in uids do
		data.pets[uid] = nil
		StateReplicator.set(userId, `pets.{uid}`, nil)
	end

	local creature = Creatures.get(result.id)
	local petUid = newUid()
	local gender = if rng:chance(0.5) then "M" else "F"
	PetService.addPet(userId, petUid, {
		id = result.id,
		kg = result.kg,
		g = gender,
		muts = result.muts,
		eq = false,
		lock = false,
		t = Clock.now(),
	})
	local isNew = IndexService.markFound(userId, result.id)

	local payload = {
		petUid = petUid,
		speciesId = creature.id,
		name = creature.name,
		rarity = creature.rarity,
		muts = result.muts,
		kg = result.kg,
		gender = gender,
		income = PetMath.petIncome(creature.id, result.kg, result.muts),
		isNew = isNew,
		upgraded = result.upgraded,
		prism = result.prism,
	}
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("FuseResult", player, payload)
	end
	return true, payload
end

local function buildStall()
	local cfg = CollectionConfig.fuse
	local parent = workspace:FindFirstChild(Types.Names.Map) or workspace
	local model = Instance.new("Model")
	model.Name = "FuseStall"

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local base = Vector3.new(cfg.x, cfg.y, cfg.z)
	local steel = Color3.fromRGB(120, 130, 150)
	local body = block(
		"Machine",
		Vector3.new(12, 8, 6),
		base + Vector3.new(0, 4, 0),
		steel,
		Enum.Material.Metal
	)
	block(
		"Hood",
		Vector3.new(13, 1.5, 7),
		base + Vector3.new(0, 8.75, 0),
		Color3.fromRGB(255, 190, 40)
	)
	-- Tiga lubang input (slot) di bagian depan (-Z) dengan lampu kecil.
	for i = -1, 1 do
		block(
			"Slot" .. (i + 2),
			Vector3.new(2.6, 3, 0.6),
			base + Vector3.new(i * 3.6, 5.2, -3.1),
			Color3.fromRGB(35, 35, 45)
		)
		local lamp = block(
			"Lamp" .. (i + 2),
			Vector3.new(1, 1, 0.5),
			base + Vector3.new(i * 3.6, 3, -3.2),
			Color3.fromRGB(255, 120, 220),
			Enum.Material.Neon
		)
		lamp.Shape = Enum.PartType.Ball
	end
	block(
		"Chute",
		Vector3.new(4, 1.2, 3),
		base + Vector3.new(0, 1.4, -4.5),
		Color3.fromRGB(90, 100, 120),
		Enum.Material.Metal
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(280, 60)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 200
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Fuse Machine"
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = cfg.promptName
	prompt.ActionText = "Fuse Creatures"
	prompt.ObjectText = "Fuse Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.Parent = parent
end

function FuseService.Init()
	buildStall()

	TestBridge.register("fuse.fuse", function(userId, uids)
		local ok, result = FuseService.fuse(userId, uids)
		return { ok = ok, result = result }
	end)
	TestBridge.register("fuse.seed", function(seed)
		FuseService.setSeed(seed)
		return true
	end)
end

function FuseService.Start()
	Net.on(
		"FuseSubmit",
		Check.args(Check.uidList(CollectionConfig.fuse.petCount)),
		function(player, uids)
			local ok, err = FuseService.fuse(player.UserId, uids)
			if not ok then
				Net.fire("Notify", player, tostring(err), "error")
			end
		end
	)
end

return FuseService
