--!nonstrict
-- Banner zona di atas layar: nama zona, Danger Meter (5 kotak), dan "Recommended speed".
-- Zona dihitung lokal dari Z root karakter (4 Hz); banner muncul saat zona berubah lalu pudar (~2.5 detik).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local NumberFormat = require(Shared.Logic.NumberFormat)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local StateController = require(script.Parent.StateController)

local ZoneBannerController = {}

local SAMPLE_INTERVAL = 0.25
local FADE_IN = 0.3
local HOLD = 1.9
local FADE_OUT = 0.3
local DANGER_ICONS = 5

local gui, group, nameLabel, recLabel
local icons = {}
local currentZone = nil
local shownZone = nil
local showId = 0
local accumulator = 0

local function playerSpeed(): number
	return StateController.get("speedEffective") or StateController.get("speedBase") or 0
end

local function refreshRecommended()
	if not shownZone then
		return
	end
	local zone = Zones.get(shownZone)
	if zone.recSpeed <= 0 then
		recLabel.Text = "Starter zone"
		recLabel.TextColor3 = Theme.Colors.White
		return
	end
	recLabel.Text = "Recommended speed: " .. NumberFormat.fmt(zone.recSpeed)
	recLabel.TextColor3 = if playerSpeed() < zone.recSpeed
		then Theme.Colors.Brick
		else Theme.Colors.White
end

local function show(zoneIndex: number)
	local zone = Zones.get(zoneIndex)
	shownZone = zoneIndex
	nameLabel.Text = zone.name
	for i, icon in icons do
		icon.BackgroundTransparency = if i <= zone.danger then 0 else 1
	end
	refreshRecommended()

	showId += 1
	local mine = showId
	group.Visible = true
	group.GroupTransparency = 1
	TweenService:Create(group, TweenInfo.new(FADE_IN), { GroupTransparency = 0 }):Play()
	task.delay(FADE_IN + HOLD, function()
		if mine ~= showId then
			return
		end
		TweenService:Create(group, TweenInfo.new(FADE_OUT), { GroupTransparency = 1 }):Play()
		task.delay(FADE_OUT, function()
			if mine == showId then
				group.Visible = false
				shownZone = nil
			end
		end)
	end)
end

local function sample()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local zone = Layout.zoneAtZ(root.Position.Z)
	if zone ~= currentZone then
		currentZone = zone
		if zone then
			show(zone)
		end
	end
end

local function label(props)
	props.BackgroundTransparency = 1
	return UIBuilder.create("TextLabel", props)
end

function ZoneBannerController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "ZoneBanner",
		ResetOnSpawn = false,
		DisplayOrder = 15,
	})
	group = UIBuilder.create("CanvasGroup", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(340, 92),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	nameLabel = label({
		Name = "ZoneName",
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Fonts.Title,
		TextSize = 34,
		TextColor3 = Theme.Colors.Yolk,
		Text = "",
		Parent = group,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 3, Color = Theme.Colors.Brown }),
		},
	})
	local meter = UIBuilder.create("Frame", {
		Name = "Danger",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(DANGER_ICONS * 22, 18),
		BackgroundTransparency = 1,
		Parent = group,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
		},
	})
	for i = 1, DANGER_ICONS do
		icons[i] = UIBuilder.create("Frame", {
			Name = "Icon" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Theme.Colors.Brick,
			BorderSizePixel = 0,
			Parent = meter,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 5) }),
				UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brick }),
			},
		})
	end
	recLabel = label({
		Name = "Recommended",
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Fonts.Title,
		TextSize = 20,
		TextColor3 = Theme.Colors.White,
		Text = "",
		Parent = group,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})

	StateController.changed:Connect(function(path)
		if path == "*" or path == "speedBase" or path == "speedEffective" then
			refreshRecommended()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		sample()
	end)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return ZoneBannerController
