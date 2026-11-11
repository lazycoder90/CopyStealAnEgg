--!nonstrict
-- FreeBasketService: keranjang gratis tiap 15 menit. Kios global di hub, cooldown per pemain.
-- data.freeBasketAt = Clock.now() saat klaim berikutnya boleh (0 = tersedia).
-- Klaim lewat ProximityPrompt (server) ATAU remote ClaimFreeBasket. Klien tidak bisa membandingkan
-- Clock.now() dengan os.time(), maka server mereplikasi `freeBasketIn` (sisa detik) tiap 5 detik.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BasketRoll = require(Shared.Logic.BasketRoll)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Layout = require(Shared.Config.Layout)
local NumberFormat = require(Shared.Logic.NumberFormat)
local RNG = require(Shared.Logic.RNG)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local HatchService = require(script.Parent.HatchService)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)

local FreeBasketService = {}

local cfg = EconomyConfig.basket
local RESEND_SECONDS = 5

local rng = RNG.new(os.time() + 31)
local lastSent = {} -- [userId] = sisa detik terakhir yang dikirim
local prompt

function FreeBasketService.setSeed(seed: number)
	rng:reseed(seed)
end

local function remaining(data): number
	return math.max(0, math.ceil((data.freeBasketAt or 0) - Clock.now()))
end

local function replicateRemaining(userId: number, force: boolean?)
	local data = DataService.getByUserId(userId)
	if not data then
		return
	end
	local left = remaining(data)
	if force or left > 0 or lastSent[userId] ~= 0 then
		lastSent[userId] = left
		StateReplicator.set(userId, "freeBasketIn", left)
	end
end

-- Pengali peluang mutasi saat menetas (Lucky Potion aktif = x2).
function FreeBasketService.luckMultiplier(userId: number): number
	local data = DataService.getByUserId(userId)
	if data and data.boosts and (data.boosts.lucky2xUntil or 0) > Clock.now() then
		return cfg.luckMult
	end
	return 1
end

local function extendBoost(userId: number, data, field: string, seconds: number)
	local now = Clock.now()
	data.boosts[field] = math.max(data.boosts[field] or 0, now + seconds)
	StateReplicator.set(userId, `boosts.{field}`, data.boosts[field])
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function formatLeft(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Mengembalikan true, jenisHadiah | false, pesanGalat, sisaDetik?
function FreeBasketService.claim(userId: number): (boolean, string, number?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	local left = remaining(data)
	if left > 0 then
		return false, `Basket ready in {formatLeft(left)}`, left
	end

	-- Atomik, tanpa yield.
	local kind = BasketRoll.roll(rng)
	local text
	if kind == "cash" then
		local amount = math.max(cfg.cashMin, (data.lastIncomePerSec or 0) * cfg.cashSeconds)
		CurrencyService.add(userId, "cash", amount)
		text = NumberFormat.fmtMoney(amount)
	elseif kind == "speed" then
		extendBoost(userId, data, "speed2xUntil", cfg.speedSeconds)
		SpeedService.refresh(userId)
		text = "Speed Potion (5 min)"
	elseif kind == "growth" then
		extendBoost(userId, data, "growth2xUntil", cfg.growthSeconds)
		text = "Growth Boost (5 min)"
	else
		extendBoost(userId, data, "lucky2xUntil", cfg.luckSeconds)
		text = "Lucky Potion (10 min)"
	end

	data.freeBasketAt = Clock.now() + cfg.cooldown
	StateReplicator.set(userId, "freeBasketAt", data.freeBasketAt)
	replicateRemaining(userId, true)
	notify(userId, `Free Basket: {text}`, "success")
	return true, kind
end

local function buildStall()
	local parent = workspace:FindFirstChild(Types.Names.Map) or workspace
	local pos = Layout.hubStalls.basket
	local base = Vector3.new(pos.x, 0, pos.z)
	local model = Instance.new("Model")
	model.Name = "FreeBasketStall"

	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = base + offset
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local wicker = Color3.fromRGB(196, 146, 84)
	local body =
		block("Basket", Vector3.new(7, 3.5, 5), Vector3.new(0, 1.75, 0), wicker, Enum.Material.Wood)
	block(
		"Rim",
		Vector3.new(7.6, 0.6, 5.6),
		Vector3.new(0, 3.8, 0),
		Color3.fromRGB(150, 104, 62),
		Enum.Material.Wood
	)
	block(
		"Cloth",
		Vector3.new(6.4, 0.3, 4.6),
		Vector3.new(0, 4.2, 0),
		Color3.fromRGB(214, 70, 60),
		Enum.Material.Fabric
	)
	block(
		"HandleL",
		Vector3.new(0.5, 4, 0.5),
		Vector3.new(-3.2, 5.8, 0),
		wicker,
		Enum.Material.Wood
	)
	block("HandleR", Vector3.new(0.5, 4, 0.5), Vector3.new(3.2, 5.8, 0), wicker, Enum.Material.Wood)
	local bar = block(
		"HandleTop",
		Vector3.new(7, 0.5, 0.5),
		Vector3.new(0, 7.9, 0),
		wicker,
		Enum.Material.Wood
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(240, 56)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 200
	gui.Parent = bar
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "FREE BASKET"
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.Parent = gui

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = cfg.promptName
	prompt.ActionText = "Claim"
	prompt.ObjectText = "Free Basket"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.Parent = parent
end

local function claimAndTell(player: Player)
	local ok, result = FreeBasketService.claim(player.UserId)
	if not ok then
		Net.fire("Notify", player, result, "error")
	end
end

function FreeBasketService.Init()
	HatchService.addLuckProvider("lucky", FreeBasketService.luckMultiplier)
	buildStall()

	-- order 1100: setelah snapshot StateReplicator (1000).
	PlayerLifecycle.onJoin("FreeBasketService.replicate", 1100, function(ctx)
		lastSent[ctx.userId] = nil
		if ctx.player then
			replicateRemaining(ctx.userId, true)
		end
	end)
	PlayerLifecycle.onLeaving("FreeBasketService", 100, function(ctx)
		lastSent[ctx.userId] = nil
	end)

	TestBridge.register("basket.claim", function(userId)
		local ok, result, left = FreeBasketService.claim(userId)
		return { ok = ok, result = result, remaining = left }
	end)
	TestBridge.register("basket.setSeed", function(seed)
		FreeBasketService.setSeed(seed)
		return true
	end)
	TestBridge.register("basket.luck", FreeBasketService.luckMultiplier)
end

function FreeBasketService.Start()
	prompt.Triggered:Connect(claimAndTell)
	Net.on("ClaimFreeBasket", Check.args(), claimAndTell)

	-- Handler kedua ClientReady: kirim sisa waktu setelah StateReplicator siap menerima patch.
	Net.on("ClientReady", Check.args(), function(player)
		task.delay(0.5, function()
			replicateRemaining(player.UserId, true)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(RESEND_SECONDS)
			for _, entry in DataService.all() do
				if entry.player then
					replicateRemaining(entry.userId)
				end
			end
		end
	end)
end

return FreeBasketService
