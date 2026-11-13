--!nonstrict
-- WheelService: Sprint Wheel (conveyor bundar di tiap Coop). Pemilik yang terus berlari di atas roda
-- mendapat step 3/detik (server yang menghitung); setiap step menambah speedBase. Pemain yang diam
-- terdorong keluar oleh conveyor. Upgrade level lewat prompt di papan roda atau remote UpgradeWheel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Progression = require(Shared.Config.Progression)
local Layout = require(Shared.Config.Layout)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AntiExploit = require(script.Parent.AntiExploit)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr = Types.Names, Types.Attr

local WheelService = {}

local RADIUS = 14
local WHEEL_LOCAL = Layout.plotReserved[2] -- pusat roda (lokal), sama dengan area terlarang
local CONVEYOR_SPEED = 12
local TICK = 0.1
local GRACE = 0.6
local ROBUX_MESSAGE = "Robux purchase is not available yet"

local PLATFORM = "Platform"
local SIGN = "WheelSign"

local stepAcc = {} -- [userId] = pecahan step

local function money(n: number): string
	return "$" .. NumberFormat.fmt(n)
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function part(parent: Instance, name: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function wheelOf(plot: Model): Model?
	return plot and plot:FindFirstChild(Names.PlotWheel)
end

local function buildWheel(plot: Model)
	local floor = PlotService.getFloor(plot)
	local center = PlotService.localToWorld(plot, WHEEL_LOCAL.x, WHEEL_LOCAL.z)
	local model = Instance.new("Model")
	model.Name = Names.PlotWheel

	-- Piringan conveyor: Cylinder berporos X diputar 90 derajat sehingga datar.
	local platform = part(model, PLATFORM, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, RADIUS * 2, RADIUS * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 70, 86),
		Material = Enum.Material.Metal,
	})
	platform.AssemblyLinearVelocity =
		floor.CFrame:VectorToWorldSpace(Vector3.new(0, 0, CONVEYOR_SPEED))
	model.PrimaryPart = platform

	-- Pita hijau tengah (dekorasi) dan cincin rel dari balok neon kecil tanpa tabrakan.
	part(model, "Hub", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 6, 6),
		CFrame = CFrame.new(center + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 190, 40),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
	})
	local segments = 24
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * RADIUS, 0.9, math.sin(angle) * RADIUS)
		part(model, "RailSegment", {
			Size = Vector3.new(1.2, 0.6, 3),
			CFrame = CFrame.lookAt(pos, center) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(255, 190, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Papan di pagar barat (menghadap +X): label level dan prompt upgrade.
	local signPos = PlotService.localToWorld(plot, -39.2, 0) + Vector3.new(0, 4, 0)
	local signWorld = Vector3.new(signPos.X, signPos.Y, center.Z)
	local sign = part(model, SIGN, {
		Size = Vector3.new(0.6, 4, 9),
		Position = signWorld,
		Color = Color3.fromRGB(110, 76, 44),
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(280, 80)
	gui.StudsOffset = Vector3.new(3, 2.5, 0)
	gui.MaxDistance = 90
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 226, 120)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	title.Text = "Sprint Wheel"
	title.Parent = gui
	local info = title:Clone()
	info.Name = "Info"
	info.Position = UDim2.fromScale(0, 0.45)
	info.Size = UDim2.fromScale(1, 0.55)
	info.Font = Enum.Font.GothamBold
	info.TextColor3 = Color3.fromRGB(255, 255, 255)
	info.Text = ""
	info.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Upgrade Wheel"
	prompt.ObjectText = "Sprint Wheel"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = sign
	prompt.Triggered:Connect(function(player)
		local owner = PlotService.getOwnerUserId(plot)
		if owner ~= player.UserId then
			Net.fire("Notify", player, "This is not your Sprint Wheel.", "error")
			return
		end
		local ok, err = WheelService.upgrade(player.UserId, "cash")
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)

	model.Parent = plot
	return model
end

-- Perbarui atribut dan papan roda dari data pemilik (atau tampilan default jika plot kosong).
local function updateVisual(plot: Model, data)
	local model = wheelOf(plot)
	if not model then
		return
	end
	local level = data and data.wheelLevel or 1
	model:SetAttribute(Attr.WheelLevel, level)
	model:SetAttribute(Attr.WheelGain, Formulas.wheelGainPerStep(level))
	local sign = model:FindFirstChild(SIGN)
	local gui = sign and sign:FindFirstChild("Sign")
	local info = gui and gui:FindFirstChild("Info")
	if info then
		if level >= Progression.wheel.maxLevel then
			info.Text = `Level {level} (MAX)`
		else
			info.Text = `Level {level} > {level + 1}  {money(Formulas.wheelUpgradePrice(level))}`
		end
	end
end

function WheelService.refresh(userId: number)
	local plot = PlotService.getPlot(userId)
	if plot then
		updateVisual(plot, DataService.getByUserId(userId))
	end
end

-- Menaikkan level roda. Mengembalikan ok, errPesan.
function WheelService.upgrade(userId: number, currency: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	if currency == "robux" then
		return false, ROBUX_MESSAGE
	end
	if currency ~= "cash" then
		return false, "Invalid currency."
	end
	local level = data.wheelLevel
	if level >= Progression.wheel.maxLevel then
		return false, "Your Sprint Wheel is already at max level."
	end
	if not CurrencyService.trySpend(userId, "cash", Formulas.wheelUpgradePrice(level)) then
		return false, "Not enough cash."
	end
	data.wheelLevel = level + 1
	StateReplicator.set(userId, "wheelLevel", data.wheelLevel)
	WheelService.refresh(userId)
	notify(userId, "Successfully upgraded your Sprint Wheel!", "success")
	return true
end

-- Menaikkan level roda 1 tingkat tanpa biaya (produk Robux). false bila sudah maksimum.
function WheelService.grantLevel(userId: number): boolean
	local data = DataService.getByUserId(userId)
	if not data or data.wheelLevel >= Progression.wheel.maxLevel then
		return false
	end
	data.wheelLevel += 1
	StateReplicator.set(userId, "wheelLevel", data.wheelLevel)
	WheelService.refresh(userId)
	notify(userId, "Your Sprint Wheel gained a level!", "success")
	return true
end

-- Satu tick untuk satu pemain. movingOverride (uji) menggantikan MoveDirection.
-- Mengembalikan speed yang diberikan pada tick ini.
local function tickPlayer(userId: number, dt: number, movingOverride: boolean?): number
	local plot = PlotService.getPlot(userId)
	local model = wheelOf(plot)
	local platform = model and model:FindFirstChild(PLATFORM)
	local root = Actors.getRoot(userId)
	local humanoid = Actors.getHumanoid(userId)
	if not (platform and root and humanoid) or humanoid.Health <= 0 then
		stepAcc[userId] = nil
		return 0
	end
	local offset = root.Position - platform.Position
	local onWheel = Vector3.new(offset.X, 0, offset.Z).Magnitude <= RADIUS
		and offset.Y > -2
		and offset.Y < 8
	if not onWheel then
		stepAcc[userId] = nil
		return 0
	end
	AntiExploit.grace(userId, GRACE, "wheel")
	local moving = movingOverride
	if moving == nil then
		moving = humanoid.MoveDirection.Magnitude > 0
	end
	if not moving then
		return 0
	end

	local acc = (stepAcc[userId] or 0) + dt * Progression.wheel.stepsPerSecond
	local steps = math.floor(acc + 1e-6)
	stepAcc[userId] = math.max(acc - steps, 0)
	if steps <= 0 then
		return 0
	end
	local data = DataService.getByUserId(userId)
	if not data then
		return 0
	end
	local gain = Formulas.wheelGainPerStep(data.wheelLevel) * steps
	CurrencyService.add(userId, "speedBase", gain)
	SpeedService.refresh(userId)
	return gain
end

function WheelService.Init()
	-- Systems (MapBuilder) sudah selesai Init, jadi semua Plot ada.
	local plots = workspace:FindFirstChild(Names.Plots)
	for i = 1, Layout.plotCount do
		local plot = plots and plots:FindFirstChild(`Plot_{i}`)
		if plot and not wheelOf(plot) then
			buildWheel(plot)
			updateVisual(plot, nil)
		end
	end

	PlayerLifecycle.onJoin("WheelService", 100, function(ctx)
		stepAcc[ctx.userId] = nil
		WheelService.refresh(ctx.userId)
	end)
	PlayerLifecycle.onLeaving("WheelService", 80, function(ctx)
		stepAcc[ctx.userId] = nil
		local plot = PlotService.getPlot(ctx.userId)
		if plot then
			updateVisual(plot, nil)
		end
	end)

	InvariantChecker.register("Wheel", function(entry)
		local out = {}
		local level = entry.data.wheelLevel
		if type(level) ~= "number" or level < 1 or level > Progression.wheel.maxLevel then
			table.insert(out, `wheelLevel di luar batas: {tostring(level)}`)
		end
		return out
	end)

	TestBridge.register("wheel.tick", function(userId, moving)
		return tickPlayer(userId, 1 / Progression.wheel.stepsPerSecond, moving)
	end)
	TestBridge.register("wheel.upgrade", WheelService.upgrade)
	TestBridge.register("wheel.info", function(userId)
		local plot = PlotService.getPlot(userId)
		local model = wheelOf(plot)
		local platform = model and model:FindFirstChild(PLATFORM)
		if not platform then
			return nil
		end
		return {
			level = model:GetAttribute(Attr.WheelLevel),
			gain = model:GetAttribute(Attr.WheelGain),
			center = { platform.Position.X, platform.Position.Y, platform.Position.Z },
			radius = RADIUS,
		}
	end)

	AdminService.register("wheel", function(player, args)
		local level = tonumber(args[1])
		local data = DataService.getByUserId(player.UserId)
		if not (data and level and level >= 1 and level <= Progression.wheel.maxLevel) then
			return `Pakai: wheel <1..{Progression.wheel.maxLevel}>`
		end
		data.wheelLevel = math.floor(level)
		StateReplicator.set(player.UserId, "wheelLevel", data.wheelLevel)
		WheelService.refresh(player.UserId)
		return `wheelLevel = {data.wheelLevel}`
	end)
end

function WheelService.Start()
	Net.on("UpgradeWheel", Check.args(Check.enum({ "cash", "robux" })), function(player, currency)
		local ok, err = WheelService.upgrade(player.UserId, currency)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		local step = acc
		acc = 0
		for _, entry in DataService.all() do
			tickPlayer(entry.userId, step)
		end
	end)
end

return WheelService
