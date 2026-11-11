--!nonstrict
-- Chip siang/malam di kanan bawah (ikon matahari/bulan + "in 4m 19s"), BigCountdown 10 detik terakhir
-- dan tint layar halus saat malam. Server mengirim sisa detik; klien menghitung mundur sendiri.
-- Controller ini juga menyediakan tumpukan chip kanan bawah (getChipStack) dan BigCountdown bersama (setBig).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CycleMath = require(Shared.Logic.CycleMath)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local DayNightController = {}

local SUN_COLOR = Color3.fromRGB(255, 214, 64)
local MOON_COLOR = Color3.fromRGB(205, 220, 255)
local CHIP_DAY = Color3.fromRGB(255, 244, 222)
local CHIP_NIGHT = Color3.fromRGB(40, 52, 96)
local NIGHT_TINT = Color3.fromRGB(170, 195, 255)
local BIG_ORDER = { "reset", "daynight" } -- yang lebih awal menang bila dua-duanya aktif

local gui, stack, bigLabel, iconSun, iconBite, timeLabel, chip, chipStroke
local tint
local state = "Day"
local endsAt = nil -- os.clock() saat fase berakhir
local bigTexts = {}
local accumulator = 0

local function ensureGui()
	if gui then
		return
	end
	gui = UIBuilder.create("ScreenGui", {
		Name = "WorldEventHUD",
		ResetOnSpawn = false,
		DisplayOrder = 14,
	})
	stack = UIBuilder.create("Frame", {
		Name = "ChipStack",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(200, 100),
		BackgroundTransparency = 1,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
			}),
		},
	})
	bigLabel = UIBuilder.create("TextLabel", {
		Name = "BigCountdown",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(420, 64),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 52,
		TextColor3 = Theme.Colors.Yolk,
		Text = "",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
		},
	})
	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

-- Tumpukan chip kanan bawah (LayoutOrder kecil = di atas).
function DayNightController.getChipStack(): Frame
	ensureGui()
	return stack
end

-- BigCountdown bersama: owner = "reset" | "daynight"; text nil menyembunyikan milik owner itu.
function DayNightController.setBig(owner: string, text: string?)
	ensureGui()
	bigTexts[owner] = text
	local shown
	for _, key in BIG_ORDER do
		if bigTexts[key] then
			shown = bigTexts[key]
			break
		end
	end
	bigLabel.Visible = shown ~= nil
	bigLabel.Text = shown or ""
end

local function buildChip()
	chip = UIBuilder.create("Frame", {
		Name = "DayNightChip",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = CHIP_DAY,
		BorderSizePixel = 0,
		Parent = stack,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		},
	})
	chipStroke = UIBuilder.create("UIStroke", {
		Thickness = Theme.StrokeThickness,
		Color = Theme.Colors.Brown,
		Parent = chip,
	})
	iconSun = UIBuilder.create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = SUN_COLOR,
		BorderSizePixel = 0,
		Parent = chip,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		},
	})
	-- "Gigitan" bulan sabit: lingkaran warna chip yang menutup sebagian ikon (hanya terlihat saat malam).
	iconBite = UIBuilder.create("Frame", {
		Name = "Bite",
		Position = UDim2.fromOffset(8, -3),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = CHIP_NIGHT,
		BorderSizePixel = 0,
		Visible = false,
		Parent = iconSun,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		},
	})
	timeLabel = UIBuilder.create("TextLabel", {
		Name = "Time",
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -48, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Title,
		TextSize = 20,
		TextColor3 = Theme.Colors.Brown,
		Text = "",
		Parent = chip,
	})
end

local function remainingNow(): number
	return if endsAt then math.max(0, endsAt - os.clock()) else 0
end

local function applyTint()
	if not tint then
		return
	end
	local night = state == "Night"
	TweenService:Create(tint, TweenInfo.new(3), {
		TintColor = if night then NIGHT_TINT else Color3.new(1, 1, 1),
		Saturation = if night then -0.1 else 0,
	}):Play()
end

local function applyState()
	local night = state == "Night"
	iconSun.BackgroundColor3 = if night then MOON_COLOR else SUN_COLOR
	iconBite.Visible = night
	chip.BackgroundColor3 = if night then CHIP_NIGHT else CHIP_DAY
	iconBite.BackgroundColor3 = chip.BackgroundColor3
	timeLabel.TextColor3 = if night then Theme.Colors.White else Theme.Colors.Brown
	chipStroke.Color = if night then MOON_COLOR else Theme.Colors.Brown
	applyTint()
end

local function refresh()
	local remaining = remainingNow()
	timeLabel.Text = "in " .. CycleMath.format(remaining)
	DayNightController.setBig("daynight", CycleMath.countdownLabel(state, remaining))
end

function DayNightController.Start()
	ensureGui()
	buildChip()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "NightTint"
	tint.Parent = Lighting
	applyState()
	timeLabel.Text = ""

	Net.connect("DayNight", function(payload)
		if type(payload) ~= "table" or type(payload.remaining) ~= "number" then
			return
		end
		local changed = payload.state ~= state
		state = if payload.state == "Night" then "Night" else "Day"
		endsAt = os.clock() + payload.remaining
		if changed then
			applyState()
		end
		refresh()
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 or not endsAt then
			return
		end
		accumulator = 0
		refresh()
	end)
end

return DayNightController
