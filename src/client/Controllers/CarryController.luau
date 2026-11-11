--!nonstrict
-- Tampilan saat membawa telur: banner RUN!!, vignette merah, tombol Drop (key G), chip info.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local ModelFactory = require(Shared.ModelFactory)
local Signal = require(Shared.Util.Signal)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local NotificationController = require(script.Parent.NotificationController)

local CarryController = {}
CarryController.changed = Signal.new() -- (carrying: boolean, payload)

local payload = nil
local gui, banner, chip, chipName, chipIncome, dropButton, caught, vignette
local pulseTweens = {}
local caughtId = 0

local function pulse(instance, goal, duration: number)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	tween:Play()
	table.insert(pulseTweens, tween)
end

local function stopPulses()
	for _, tween in pulseTweens do
		tween:Cancel()
	end
	table.clear(pulseTweens)
end

local function setVisible(visible: boolean)
	banner.Visible = visible
	chip.Visible = visible
	dropButton.Visible = visible
	vignette.Visible = visible
	stopPulses()
	if visible then
		banner.Size = UDim2.fromOffset(220, 64)
		pulse(banner, { Size = UDim2.fromOffset(244, 70) }, 0.35)
		for _, edge in vignette:GetChildren() do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = 0.2
				pulse(edge, { BackgroundTransparency = 0.5 }, 0.5)
			end
		end
	end
end

local function flashCaught()
	caughtId += 1
	local mine = caughtId
	caught.Visible = true
	caught.TextTransparency = 0
	task.delay(0.6, function()
		if mine ~= caughtId then
			return
		end
		TweenService:Create(caught, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			if mine == caughtId then
				caught.Visible = false
			end
		end)
	end)
end

local function onCarryChanged(data)
	if type(data) ~= "table" then
		return
	end
	if data.state == "Carrying" then
		payload = data
		chipName.Text = tostring(data.name or "Egg")
		chipName.TextColor3 = ModelFactory.rarityColor(data.rarity or 1)
		chipIncome.Text = NumberFormat.fmtRate(data.projectedIncome or 0)
		setVisible(true)
		CarryController.changed:Fire(true, data)
	else
		payload = nil
		setVisible(false)
		local reason = data.reason
		if reason == "caught" then
			flashCaught()
		elseif reason == "dropped" or reason == "died" then
			NotificationController.push(
				reason == "died" and "You dropped the egg." or "Egg dropped.",
				"info"
			)
		elseif reason == "placed" then
			NotificationController.push("Egg placed!", "success")
		end
		CarryController.changed:Fire(false, data)
	end
end

function CarryController.isCarrying(): boolean
	return payload ~= nil
end

function CarryController.getPayload()
	return payload
end

function CarryController.drop()
	if payload then
		Net.send("DropEgg")
	end
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = Theme.Fonts.Title
	return UIBuilder.create("TextLabel", props)
end

function CarryController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Carry",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
	})

	vignette = UIBuilder.create("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local edges = {
		{ "Top", UDim2.fromScale(1, 0.18), Vector2.new(0, 0), UDim2.fromScale(0, 0), 90 },
		{ "Bottom", UDim2.fromScale(1, 0.18), Vector2.new(0, 1), UDim2.fromScale(0, 1), 270 },
		{ "Left", UDim2.fromScale(0.12, 1), Vector2.new(0, 0), UDim2.fromScale(0, 0), 0 },
		{ "Right", UDim2.fromScale(0.12, 1), Vector2.new(1, 0), UDim2.fromScale(1, 0), 180 },
	}
	for _, e in edges do
		UIBuilder.create("Frame", {
			Name = e[1],
			Size = e[2],
			AnchorPoint = e[3],
			Position = e[4],
			BackgroundColor3 = Theme.Colors.Brick,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = vignette,
			[UIBuilder.Children] = {
				UIBuilder.create("UIGradient", {
					Rotation = e[5],
					Transparency = NumberSequence.new(0, 1),
				}),
			},
		})
	end

	banner = label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(220, 64),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Brick,
		TextSize = 40,
		TextColor3 = Theme.Colors.White,
		Text = "RUN!!",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", {
				Thickness = 3,
				Color = Theme.Colors.Brown,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		},
	})

	chip = UIBuilder.create("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(220, 50),
		BackgroundColor3 = Theme.Colors.Cream,
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create(
				"UIStroke",
				{ Thickness = Theme.StrokeThickness, Color = Theme.Colors.Brown }
			),
		},
	})
	chipName = label({
		Name = "Name",
		Size = UDim2.new(1, -8, 0, 26),
		Position = UDim2.fromOffset(4, 2),
		TextSize = 20,
		TextColor3 = Theme.Colors.White,
		Text = "",
		Parent = chip,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	chipIncome = label({
		Name = "Income",
		Size = UDim2.new(1, -8, 0, 20),
		Position = UDim2.fromOffset(4, 28),
		Font = Theme.Fonts.Body,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(40, 130, 60),
		Text = "",
		Parent = chip,
	})

	dropButton = Button.new({
		name = "Drop",
		text = "Drop (G)",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -24),
		size = UDim2.fromOffset(150, 48),
		onClick = CarryController.drop,
		parent = gui,
	})
	dropButton.Visible = false

	caught = label({
		Name = "Caught",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(400, 90),
		TextSize = 72,
		TextColor3 = Theme.Colors.Brick,
		Text = "CAUGHT!",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
		},
	})

	Net.connect("CarryChanged", onCarryChanged)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			CarryController.drop()
		end
	end)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return CarryController
