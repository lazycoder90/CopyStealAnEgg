--!nonstrict
-- TrailService: beli/pasang Trail (hanya satu aktif). Trail aktif menjadi pengali Speed lewat
-- SpeedService.addMultiplier, dan digambar sebagai Trail di HRP karakter. Kios "TRAILS SHOP"
-- di hub; klien membuka toko lewat ProximityPromptService (tanpa remote).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names = Types.Names

local TrailService = {}

local ROBUX_MESSAGE = "Robux purchase is not available yet"
local FX_NAME = "TrailFx"

local byId = {}
for _, trail in Progression.trails do
	byId[trail.id] = trail
end

local maids = {} -- [userId] = Maid (koneksi CharacterAdded)
local fx = {} -- [userId] = { trail, a0, a1 }

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

function TrailService.get(id: string)
	return byId[id]
end

local function clearVisual(userId: number)
	local items = fx[userId]
	if items then
		for _, inst in items do
			inst:Destroy()
		end
		fx[userId] = nil
	end
end

-- Buat ulang efek Trail di HRP sesuai trail yang dipasang.
local function applyVisual(userId: number)
	clearVisual(userId)
	local data = DataService.getByUserId(userId)
	local def = data and data.trails.equipped and byId[data.trails.equipped]
	local root = Actors.getRoot(userId)
	if not (def and root) then
		return
	end
	local c = def.color
	local color = Color3.fromRGB(c[1], c[2], c[3])

	local a0 = Instance.new("Attachment")
	a0.Name = FX_NAME
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = FX_NAME
	a1.Position = Vector3.new(0, -1.5, 0)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = FX_NAME
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Parent = root
	fx[userId] = { trail, a0, a1 }
end

local function setEquipped(userId: number, id)
	local data = DataService.getByUserId(userId)
	if not data then
		return
	end
	data.trails.equipped = id or false
	StateReplicator.set(userId, "trails.equipped", data.trails.equipped)
	applyVisual(userId)
	SpeedService.refresh(userId)
end

function TrailService.buy(userId: number, trailId: string, currency: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	local def = byId[trailId]
	if not data then
		return false, "Data not loaded."
	end
	if not def then
		return false, "Unknown trail."
	end
	if data.trails.owned[trailId] then
		return false, "You already own this trail."
	end
	if currency == "robux" then
		return false, ROBUX_MESSAGE
	end
	if currency ~= "cash" then
		return false, "Invalid currency."
	end
	if not CurrencyService.trySpend(userId, "cash", def.cashPrice) then
		return false, "Not enough cash."
	end
	data.trails.owned[trailId] = true
	StateReplicator.set(userId, `trails.owned.{trailId}`, true)
	notify(userId, `Unlocked the {def.name} trail!`, "success")
	return true
end

-- Memasang trail; memanggil dengan trail yang sedang dipasang (atau "") melepasnya.
function TrailService.equip(userId: number, trailId: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	if trailId == "" or data.trails.equipped == trailId then
		setEquipped(userId, nil)
		return true
	end
	if not byId[trailId] then
		return false, "Unknown trail."
	end
	if not data.trails.owned[trailId] then
		return false, "You do not own this trail."
	end
	setEquipped(userId, trailId)
	return true
end

local function buildStall()
	local shop = Progression.trailShop
	local parent = workspace:FindFirstChild(Names.Map) or workspace
	local model = Instance.new("Model")
	model.Name = "TrailsStall"

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local base = Vector3.new(shop.x, shop.y, shop.z)
	local wood = Color3.fromRGB(150, 104, 62)
	local counter = block(
		"Counter",
		Vector3.new(12, 3.5, 4),
		base + Vector3.new(0, 1.75, 0),
		wood,
		Enum.Material.Wood
	)
	block(
		"PostL",
		Vector3.new(1, 10, 1),
		base + Vector3.new(-5.5, 5, -1.5),
		wood,
		Enum.Material.Wood
	)
	block(
		"PostR",
		Vector3.new(1, 10, 1),
		base + Vector3.new(5.5, 5, -1.5),
		wood,
		Enum.Material.Wood
	)
	local roof = block(
		"Awning",
		Vector3.new(14, 1, 7),
		base + Vector3.new(0, 10, -1),
		Color3.fromRGB(255, 190, 40),
		Enum.Material.SmoothPlastic
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(280, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 200
	gui.Parent = roof
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "TRAILS SHOP"
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = shop.promptName
	prompt.ActionText = "Browse Trails"
	prompt.ObjectText = "Trails Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
end

function TrailService.Init()
	SpeedService.addMultiplier("trail", function(userId)
		local data = DataService.getByUserId(userId)
		local def = data and data.trails.equipped and byId[data.trails.equipped]
		return def and def.mult or 1
	end)

	buildStall()

	PlayerLifecycle.onJoin("TrailService", 100, function(ctx)
		local maid = Maid.new()
		maids[ctx.userId] = maid
		if ctx.player then
			maid:Give(ctx.player.CharacterAdded:Connect(function(character)
				character:WaitForChild("HumanoidRootPart", 5)
				applyVisual(ctx.userId)
			end))
		end
		applyVisual(ctx.userId)
	end)
	PlayerLifecycle.onLeaving("TrailService", 100, function(ctx)
		local maid = maids[ctx.userId]
		if maid then
			maid:Clean()
			maids[ctx.userId] = nil
		end
		clearVisual(ctx.userId)
	end)

	InvariantChecker.register("Trails", function(entry)
		local out = {}
		local trails = entry.data.trails
		for id in trails.owned do
			if not byId[id] then
				table.insert(out, `trail tidak dikenal di owned: {id}`)
			end
		end
		local equipped = trails.equipped
		if equipped and not (byId[equipped] and trails.owned[equipped]) then
			table.insert(out, `trail terpasang tidak dimiliki: {tostring(equipped)}`)
		end
		return out
	end)

	TestBridge.register("trail.buy", TrailService.buy)
	TestBridge.register("trail.equip", TrailService.equip)
	TestBridge.register("trail.hasVisual", function(userId)
		local root = Actors.getRoot(userId)
		return root ~= nil and root:FindFirstChildOfClass("Trail") ~= nil
	end)

	AdminService.register("trail", function(player, args)
		local id = args[1]
		local data = DataService.getByUserId(player.UserId)
		if not data then
			return "Data belum dimuat"
		end
		if id == "none" then
			setEquipped(player.UserId, nil)
			return "trail dilepas"
		end
		if not (id and byId[id]) then
			return "Pakai: trail <id|none>"
		end
		data.trails.owned[id] = true
		StateReplicator.set(player.UserId, `trails.owned.{id}`, true)
		setEquipped(player.UserId, id)
		return `trail = {id}`
	end)
end

function TrailService.Start()
	Net.on(
		"BuyTrail",
		Check.args(Check.str(40), Check.enum({ "cash", "robux" })),
		function(player, id, currency)
			local ok, err = TrailService.buy(player.UserId, id, currency)
			if not ok and err then
				Net.fire("Notify", player, err, "error")
			end
		end
	)
	Net.on("EquipTrail", Check.args(Check.str(40)), function(player, id)
		local ok, err = TrailService.equip(player.UserId, id)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)
end

return TrailService
