--!nonstrict
-- MutationService: "Professor Albumen" di kios "Yolk Lab" (hub). Pemain memilih mutasi (BuyMutation) lalu
-- mengklik telur miliknya yang sudah ditaruh di Coop (ApplyMutation). Harga dipotong lebih dulu, lalu roll
-- sukses; gagal = uang hilang, telur utuh (docs/PLAN.md §4.14). Pilihan berlaku 30 detik waktu NYATA.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Mutations = require(Shared.Config.Mutations)
local MutationLogic = require(Shared.Logic.MutationLogic)
local NumberFormat = require(Shared.Logic.NumberFormat)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local StateReplicator = require(script.Parent.StateReplicator)

local MutationService = {}

local rng = RNG.new(os.time() + 47)
local pending = {} -- [userId] = { mut = string, expires = os.clock() }
local ttl = CollectionConfig.mutation.pendingSeconds

function MutationService.setSeed(seed: number)
	rng:reseed(seed)
end

-- Uji: mengubah masa berlaku pilihan (detik nyata).
function MutationService.setPendingTtl(seconds: number)
	ttl = seconds
end

local function isOption(name: string): boolean
	return table.find(CollectionConfig.mutation.options, name) ~= nil
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

-- Pilihan yang masih berlaku (nama mutasi) atau nil.
function MutationService.getPending(userId: number): string?
	local p = pending[userId]
	if p and os.clock() <= p.expires then
		return p.mut
	end
	pending[userId] = nil
	return nil
end

function MutationService.select(userId: number, mutName: string): (boolean, string?)
	if mutName == CollectionConfig.mutation.cancelToken then
		pending[userId] = nil
		return true
	end
	if not isOption(mutName) then
		return false, "Unknown mutation."
	end
	pending[userId] = { mut = mutName, expires = os.clock() + ttl }
	return true
end

-- Harga mutasi untuk sebuah telur (dihitung SEBELUM mutasi ditambahkan).
function MutationService.price(egg, mutName: string): number
	return Mutations.list[mutName].npcPriceMult
		* PetMath.eggProjectedIncome(egg.id, egg.kg, egg.muts or {})
end

-- Menerapkan mutasi. forcedRoll (0..1, untuk uji) menggantikan RNG: sukses bila forcedRoll < npcSuccess.
-- Mengembalikan true + { success, mutName, price } atau false + pesan galat (pilihan tetap berlaku).
function MutationService.apply(
	userId: number,
	eggUid: string,
	mutName: string,
	forcedRoll: number?
): (boolean, any)
	local data = DataService.getByUserId(userId)
	local egg = data and data.eggs[eggUid]
	local def = Mutations.list[mutName]
	if not (egg and def and def.npcSuccess) then
		return false, "Egg not found."
	end
	if GrowthService.isFrozen(userId, eggUid) then
		return false, "Egg not found."
	end
	if egg.loc ~= "placed" then
		return false, "Place the egg in your Coop first."
	end
	egg.muts = egg.muts or {}
	if not MutationLogic.canAdd(egg.muts, mutName) then
		return false, "This egg can't take that mutation."
	end

	local price = MutationService.price(egg, mutName)
	if not CurrencyService.trySpend(userId, "cash", price) then
		return false, `Not enough cash. You need {NumberFormat.fmtMoney(price)}.`
	end

	pending[userId] = nil
	local roll = forcedRoll or rng:next()
	local success = roll < def.npcSuccess
	if success then
		egg.muts = MutationLogic.add(egg.muts, mutName)
		StateReplicator.set(userId, `eggs.{eggUid}.muts`, egg.muts)
		GrowthService.ensureModel(userId, eggUid)
		notify(userId, `{mutName} mutation applied!`, "success")
	else
		notify(userId, "The mutation failed...", "error")
	end
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("MutationResult", player, success, mutName)
	end
	return true, { success = success, mutName = mutName, price = price }
end

local function buildStall()
	local cfg = CollectionConfig.mutation
	local parent = workspace:FindFirstChild(Types.Names.Map) or workspace
	local model = Instance.new("Model")
	model.Name = "YolkLabStall"

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
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
	local base = Vector3.new(cfg.x, cfg.y, cfg.z)
	local white = Color3.fromRGB(250, 250, 245)
	local counter = block(
		"Counter",
		Vector3.new(14, 3.5, 4),
		base + Vector3.new(0, 1.75, 4),
		Color3.fromRGB(110, 150, 170),
		Enum.Material.Metal
	)
	-- Profesor ayam: badan, kepala, paruh, jengger, kacamata, jas lab.
	block("Body", Vector3.new(4, 4.5, 3), base + Vector3.new(0, 5.75, 0), white)
	block(
		"LabCoat",
		Vector3.new(4.4, 3.2, 3.4),
		base + Vector3.new(0, 5.2, 0),
		Color3.fromRGB(235, 240, 250)
	)
	block("Head", Vector3.new(3, 3, 3), base + Vector3.new(0, 9.5, 0), white)
	block(
		"Beak",
		Vector3.new(1, 0.8, 1.2),
		base + Vector3.new(0, 9.2, -2.1),
		Color3.fromRGB(255, 170, 40)
	)
	block(
		"Comb",
		Vector3.new(0.8, 1, 1.6),
		base + Vector3.new(0, 11.4, 0),
		Color3.fromRGB(220, 60, 50)
	)
	for _, side in { -1, 1 } do
		block(
			"Glass" .. (side < 0 and "L" or "R"),
			Vector3.new(1.1, 1.1, 0.3),
			base + Vector3.new(side * 0.8, 9.9, -1.6),
			Color3.fromRGB(120, 210, 255),
			Enum.Material.Glass,
			Enum.PartType.Ball
		)
	end
	block(
		"GlassBridge",
		Vector3.new(0.6, 0.2, 0.2),
		base + Vector3.new(0, 9.9, -1.6),
		Color3.fromRGB(40, 40, 50)
	)
	-- Tabung lab di meja.
	block(
		"Flask",
		Vector3.new(1.2, 1.8, 1.2),
		base + Vector3.new(4, 4.4, 4),
		Color3.fromRGB(180, 120, 255),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(300, 70)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 200
	gui.Parent = model:FindFirstChild("Comb")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Yolk Lab"
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.Parent = gui
	local sub = label:Clone()
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Text = "Professor Albumen"
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = cfg.promptName
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Professor Albumen"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
end

function MutationService.Init()
	buildStall()

	PlayerLifecycle.onLeaving("MutationService", 100, function(ctx)
		pending[ctx.userId] = nil
	end)

	TestBridge.register("mutation.apply", function(userId, eggUid, mutName, forcedRoll)
		local ok, result = MutationService.apply(userId, eggUid, mutName, forcedRoll)
		return { ok = ok, result = result }
	end)
	TestBridge.register("mutation.select", function(userId, mutName)
		local ok, err = MutationService.select(userId, mutName)
		return { ok = ok, err = err }
	end)
	TestBridge.register("mutation.pending", function(userId)
		return MutationService.getPending(userId)
	end)
	TestBridge.register("mutation.seed", function(seed)
		MutationService.setSeed(seed)
		return true
	end)
	TestBridge.register("mutation.setTtl", function(seconds)
		MutationService.setPendingTtl(seconds)
		return true
	end)
end

function MutationService.Start()
	Net.on("BuyMutation", Check.args(Check.str(20)), function(player, mutName)
		local ok, err = MutationService.select(player.UserId, mutName)
		if not ok then
			Net.fire("Notify", player, err, "error")
		end
	end)
	Net.on("ApplyMutation", Check.args(Check.uid), function(player, eggUid)
		local mutName = MutationService.getPending(player.UserId)
		if not mutName then
			Net.fire("Notify", player, "Pick a mutation from Professor Albumen first.", "error")
			return
		end
		local ok, err = MutationService.apply(player.UserId, eggUid, mutName, nil)
		if not ok then
			Net.fire("Notify", player, tostring(err), "error")
		end
	end)
end

return MutationService
