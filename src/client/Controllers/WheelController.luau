--!nonstrict
-- Label "+N" melayang di atas kepala saat speedBase naik ketika pemain berada di Sprint Wheel miliknya.
-- Delta digabung dalam jendela 0.25 detik.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Logic.NumberFormat)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local StateController = require(script.Parent.StateController)

local WheelController = {}

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags
local MERGE_WINDOW = 0.25
local player = Players.LocalPlayer

local lastSpeed
local pending = 0
local flushScheduled = false

local function ownWheelPlatform(): BasePart?
	for _, plot in CollectionService:GetTagged(Tags.Coop) do
		if plot:GetAttribute(Attr.OwnerUserId) == player.UserId then
			local wheel = plot:FindFirstChild(Names.PlotWheel)
			return wheel and wheel.PrimaryPart
		end
	end
	return nil
end

local function onWheel(root: BasePart): boolean
	local platform = ownWheelPlatform()
	if not platform then
		return false
	end
	local offset = root.Position - platform.Position
	local radius = platform.Size.Z / 2
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 1 and math.abs(offset.Y) < 8
end

local function showLabel(amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local gui = UIBuilder.create("BillboardGui", {
		Name = "WheelGain",
		Size = UDim2.fromOffset(160, 40),
		StudsOffset = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		Adornee = root,
		Parent = root,
	})
	local label = UIBuilder.create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextScaled = true,
		TextColor3 = Theme.Colors.Yolk,
		Text = "+" .. NumberFormat.fmt(amount),
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	task.delay(0.85, function()
		gui:Destroy()
	end)
end

local function flush()
	flushScheduled = false
	local amount = pending
	pending = 0
	if amount > 0 then
		showLabel(amount)
	end
end

function WheelController.Start()
	StateController.changed:Connect(function(path, value)
		if path == "*" then
			lastSpeed = value.speedBase
			return
		end
		if path ~= "speedBase" then
			return
		end
		local previous = lastSpeed
		lastSpeed = value
		if not previous or value <= previous then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and onWheel(root) then
			pending += value - previous
			if not flushScheduled then
				flushScheduled = true
				task.delay(MERGE_WINDOW, flush)
			end
		end
	end)
end

return WheelController
