--!nonstrict
-- UpgradeService: upgrade Pen (level pagar, slot telur, pet terlihat), slot equip, dan ekspansi
-- plot "Unlock: $1K". Tiga papan dengan prompt dibangun di tiap Coop; semua validasi di server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr = Types.Names, Types.Attr

local UpgradeService = {}

local FENCE_PREFIX = "Fence"
-- Posisi papan (lokal) menempel di sisi dalam pagar lane (z = +40), di luar area telur (inset 3).
local PEN_SIGN = { x = 28, z = 39.2 }
local EXPANSION_SIGN = { x = -28, z = 39.2 }

-- Tier pagar menurut level pen: kayu, batu, bata, kristal, emas, Primordial.
local function fenceTier(level: number)
	if level >= 11 then
		return {
			color = Color3.fromRGB(255, 236, 255),
			material = Enum.Material.Neon,
			transparency = 0,
		}
	elseif level >= 10 then
		return {
			color = Color3.fromRGB(255, 200, 50),
			material = Enum.Material.Metal,
			transparency = 0,
		}
	elseif level >= 7 then
		return {
			color = Color3.fromRGB(150, 225, 255),
			material = Enum.Material.Ice,
			transparency = 0.15,
		}
	elseif level >= 5 then
		return {
			color = Color3.fromRGB(176, 84, 60),
			material = Enum.Material.Brick,
			transparency = 0,
		}
	elseif level >= 3 then
		return {
			color = Color3.fromRGB(140, 140, 150),
			material = Enum.Material.Slate,
			transparency = 0,
		}
	end
	return { color = Color3.fromRGB(150, 104, 62), material = Enum.Material.Wood, transparency = 0 }
end

local function money(n: number): string
	return "$" .. NumberFormat.fmt(n)
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function plotsFolder()
	return workspace:FindFirstChild(Names.Plots)
end

local function buildSign(
	plot: Model,
	name: string,
	localPos,
	color: Color3,
	action: string,
	onTrigger
)
	local pos = PlotService.localToWorld(plot, localPos.x, localPos.z)
	local sign = Instance.new("Part")
	sign.Name = name
	sign.Size = Vector3.new(8, 4, 0.6)
	sign.Position = pos + Vector3.new(0, 3.5, 0)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Color = color
	sign.Material = Enum.Material.Wood
	sign.Parent = plot

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(260, 80)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 90
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 226, 120)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	title.Parent = gui
	local info = title:Clone()
	info.Name = "Info"
	info.Position = UDim2.fromScale(0, 0.5)
	info.Font = Enum.Font.GothamBold
	info.TextColor3 = Color3.fromRGB(255, 255, 255)
	info.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = sign
	prompt.Triggered:Connect(function(player)
		if PlotService.getOwnerUserId(plot) ~= player.UserId then
			Net.fire("Notify", player, "This is not your Coop.", "error")
			return
		end
		local ok, err = onTrigger(player.UserId)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)
	return sign
end

local function setSignText(plot: Model, signName: string, title: string, info: string)
	local sign = plot:FindFirstChild(signName)
	local gui = sign and sign:FindFirstChild("Sign")
	if gui then
		gui.Title.Text = title
		gui.Info.Text = info
	end
end

local function applyFence(plot: Model, level: number)
	local tier = fenceTier(level)
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #FENCE_PREFIX) == FENCE_PREFIX then
			child.Color = tier.color
			child.Material = tier.material
			child.Transparency = tier.transparency
		end
	end
end

-- Sinkronkan atribut, pagar, dan tiga papan dari data pemilik (nil = tampilan plot kosong).
local function updatePlot(plot: Model, data)
	local level = data and data.penLevel or 1
	plot:SetAttribute(Attr.PenLevel, level)
	applyFence(plot, level)

	if level >= Progression.maxPenLevel then
		setSignText(plot, Names.PlotPenSign, "Upgrade Pen", `Level {level} (MAX)`)
	else
		local price = Progression.pen[level + 1].price
		setSignText(
			plot,
			Names.PlotPenSign,
			"Upgrade Pen",
			`Level {level} > {level + 1}  {money(price)}`
		)
	end

	local expanded = data and data.plotExpansion or 0
	if expanded >= 1 then
		setSignText(plot, Names.PlotExpansionSign, "Plot Expansion", "Unlocked")
	else
		setSignText(
			plot,
			Names.PlotExpansionSign,
			`Unlock: {money(Progression.plotExpansion.price)}`,
			`+{Progression.plotExpansion.extraEggSlots} egg slot`
		)
	end
end

function UpgradeService.refresh(userId: number)
	local plot = PlotService.getPlot(userId)
	if plot then
		updatePlot(plot, DataService.getByUserId(userId))
	end
end

function UpgradeService.upgradePen(userId: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	local level = data.penLevel
	if level >= Progression.maxPenLevel then
		return false, "Your Coop is already at max level."
	end
	local nextPen = Progression.pen[level + 1]
	if not CurrencyService.trySpend(userId, "cash", nextPen.price) then
		return false, "Not enough cash."
	end
	data.penLevel = level + 1
	StateReplicator.set(userId, "penLevel", data.penLevel)
	UpgradeService.refresh(userId)
	PetService.refreshPlot(userId)
	notify(userId, "Successfully upgraded your Coop!", "success")
	return true
end

function UpgradeService.buyEquipSlot(userId: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	local nextSlot = data.equipSlots + 1
	local price = Progression.equipSlotPrices[nextSlot]
	if nextSlot > Progression.maxEquipSlots or not price then
		return false, "You already have the maximum equip slots."
	end
	if not CurrencyService.trySpend(userId, "cash", price) then
		return false, "Not enough cash."
	end
	data.equipSlots = nextSlot
	StateReplicator.set(userId, "equipSlots", nextSlot)
	notify(userId, `Equip slot {nextSlot} unlocked!`, "success")
	return true
end

function UpgradeService.buyPlotExpansion(userId: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded."
	end
	if data.plotExpansion >= 1 then
		return false, "You already unlocked this expansion."
	end
	if not CurrencyService.trySpend(userId, "cash", Progression.plotExpansion.price) then
		return false, "Not enough cash."
	end
	data.plotExpansion = 1
	StateReplicator.set(userId, "plotExpansion", 1)
	UpgradeService.refresh(userId)
	notify(
		userId,
		`Unlocked +{Progression.plotExpansion.extraEggSlots} egg slot in your Coop!`,
		"success"
	)
	return true
end

function UpgradeService.Init()
	-- Systems (MapBuilder) sudah selesai Init, jadi semua Plot ada.
	local plots = plotsFolder()
	for i = 1, Layout.plotCount do
		local plot = plots and plots:FindFirstChild(`Plot_{i}`)
		if plot and not plot:FindFirstChild(Names.PlotPenSign) then
			buildSign(
				plot,
				Names.PlotPenSign,
				PEN_SIGN,
				Color3.fromRGB(150, 104, 62),
				"Upgrade Pen",
				UpgradeService.upgradePen
			)
			buildSign(
				plot,
				Names.PlotExpansionSign,
				EXPANSION_SIGN,
				Color3.fromRGB(86, 140, 70),
				"Unlock",
				UpgradeService.buyPlotExpansion
			)
			updatePlot(plot, nil)
		end
	end

	-- order 100: setelah PlotService (5) memberi Coop.
	PlayerLifecycle.onJoin("UpgradeService", 100, function(ctx)
		UpgradeService.refresh(ctx.userId)
	end)
	PlayerLifecycle.onLeaving("UpgradeService", 100, function(ctx)
		local plot = PlotService.getPlot(ctx.userId)
		if plot then
			updatePlot(plot, nil)
		end
	end)

	InvariantChecker.register("Upgrades", function(entry)
		local out = {}
		local data = entry.data
		if data.penLevel < 1 or data.penLevel > Progression.maxPenLevel then
			table.insert(out, `penLevel di luar batas: {data.penLevel}`)
		end
		if
			data.equipSlots < Progression.startEquipSlots
			or data.equipSlots > Progression.maxEquipSlots
		then
			table.insert(out, `equipSlots di luar batas: {data.equipSlots}`)
		end
		if data.plotExpansion ~= 0 and data.plotExpansion ~= 1 then
			table.insert(out, `plotExpansion tidak valid: {tostring(data.plotExpansion)}`)
		end
		return out
	end)

	TestBridge.register("upgrade.pen", UpgradeService.upgradePen)
	TestBridge.register("upgrade.slot", UpgradeService.buyEquipSlot)
	TestBridge.register("upgrade.expansion", UpgradeService.buyPlotExpansion)

	AdminService.register("pen", function(player, args)
		local level = tonumber(args[1])
		local data = DataService.getByUserId(player.UserId)
		if not (data and level and level >= 1 and level <= Progression.maxPenLevel) then
			return `Pakai: pen <1..{Progression.maxPenLevel}>`
		end
		data.penLevel = math.floor(level)
		StateReplicator.set(player.UserId, "penLevel", data.penLevel)
		UpgradeService.refresh(player.UserId)
		PetService.refreshPlot(player.UserId)
		return `penLevel = {data.penLevel}`
	end)
	AdminService.register("slots", function(player, args)
		local n = tonumber(args[1])
		local data = DataService.getByUserId(player.UserId)
		if
			not (data and n and n >= Progression.startEquipSlots and n <= Progression.maxEquipSlots)
		then
			return `Pakai: slots <{Progression.startEquipSlots}..{Progression.maxEquipSlots}>`
		end
		data.equipSlots = math.floor(n)
		StateReplicator.set(player.UserId, "equipSlots", data.equipSlots)
		return `equipSlots = {data.equipSlots}`
	end)
end

function UpgradeService.Start()
	Net.on("UpgradePen", Check.args(), function(player)
		local ok, err = UpgradeService.upgradePen(player.UserId)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)
	Net.on("BuyEquipSlot", Check.args(), function(player)
		local ok, err = UpgradeService.buyEquipSlot(player.UserId)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)
end

return UpgradeService
