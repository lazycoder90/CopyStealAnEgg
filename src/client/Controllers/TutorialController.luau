--!nonstrict
-- Tutorial di klien: banner objektif per langkah, Beam panduan kuning ke target, dan tombol "Skip tutorial".
-- Sumber state: StateController "tutorial.step" / "tutorial.done" (dari TutorialService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local StateController = require(script.Parent.StateController)

local TutorialController = {}

local TEXTS = {
	"Grab an Egg!",
	"Bring it home!",
	"Place it in your Coop!",
	"Wait... then Hatch!",
	"Your creatures earn cash!",
	"Upgrade your Coop!",
	"Run on the Sprint Wheel!",
}
local UPDATE_INTERVAL = 0.25
local GUIDE_COLOR = Color3.fromRGB(255, 226, 60)

local gui, frame, objective
local guidePart, attachTarget, attachRoot, beam
local accumulator = 0

local function isActive(): boolean
	return StateController.isReady and StateController.get("tutorial.done") ~= true
end

local function ownPlot(): Model?
	local plots = workspace:FindFirstChild(Types.Names.Plots)
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute(Types.Attr.OwnerUserId) == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function positionOf(instance: Instance?): Vector3?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function nearestTagged(tag: string, root: Vector3, filter): Vector3?
	local best, bestDist
	for _, instance in CollectionService:GetTagged(tag) do
		if filter(instance) then
			local pos = positionOf(instance)
			if pos then
				local d = (pos - root).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = pos, d
				end
			end
		end
	end
	return best
end

-- Posisi target panduan untuk langkah tertentu (nil = sembunyikan beam).
local function targetFor(step: number, rootPos: Vector3): Vector3?
	if step == 1 then
		return nearestTagged(Types.Tags.WorldEgg, rootPos, function(instance)
			return instance:GetAttribute(Types.Attr.ZoneIndex) == 1
		end)
	end
	local plot = ownPlot()
	if not plot then
		return nil
	end
	if step == 2 then
		return positionOf(plot:FindFirstChild(Types.Names.PlotSpawn))
	elseif step == 3 then
		return positionOf(plot:FindFirstChild(Types.Names.PlotFloor))
	elseif step == 4 then
		return nearestTagged(Types.Tags.PlacedEgg, rootPos, function(instance)
			return instance:IsDescendantOf(plot)
		end)
	elseif step == 6 then
		return positionOf(plot:FindFirstChild(Types.Names.PlotExpansionSign))
	elseif step == 7 then
		return positionOf(plot:FindFirstChild(Types.Names.PlotWheel))
	end
	return nil
end

local function destroyGuide()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if attachRoot then
		attachRoot:Destroy()
		attachRoot = nil
	end
	if guidePart then
		guidePart:Destroy() -- ikut menghapus attachTarget
		guidePart = nil
		attachTarget = nil
	end
end

local function ensureGuide(root: BasePart)
	if guidePart and guidePart.Parent and attachRoot and attachRoot.Parent == root then
		return
	end
	destroyGuide()
	guidePart = UIBuilder.create("Part", {
		Name = "TutorialGuide",
		Size = Vector3.one,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = workspace,
	})
	attachTarget = UIBuilder.create("Attachment", { Name = "GuideTarget", Parent = guidePart })
	attachRoot = UIBuilder.create("Attachment", { Name = "TutorialGuideRoot", Parent = root })
	beam = UIBuilder.create("Beam", {
		Name = "TutorialBeam",
		Attachment0 = attachRoot,
		Attachment1 = attachTarget,
		Color = ColorSequence.new(GUIDE_COLOR),
		Width0 = 1.5,
		Width1 = 1.5,
		FaceCamera = true,
		LightEmission = 1,
		Transparency = NumberSequence.new(0.15),
		Segments = 12,
		Parent = guidePart,
	})
end

local function refresh()
	if not gui then
		return
	end
	local active = isActive()
	local step = StateController.get("tutorial.step") or 1
	local text = TEXTS[step]
	frame.Visible = active and text ~= nil
	if not (active and text) then
		destroyGuide()
		return
	end
	objective.Text = text

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pos = root and targetFor(step, root.Position)
	if not (root and pos) then
		destroyGuide()
		return
	end
	ensureGuide(root)
	guidePart.Position = pos + Vector3.new(0, 3, 0)
end

function TutorialController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		DisplayOrder = 14,
	})
	frame = UIBuilder.create("Frame", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(320, 84),
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
	objective = UIBuilder.create("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 44),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 26,
		TextWrapped = true,
		TextColor3 = Theme.Colors.Brown,
		Text = "",
		Parent = frame,
	})
	Button.new({
		name = "Skip",
		text = "Skip tutorial",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -6),
		size = UDim2.fromOffset(130, 28),
		textSize = 15,
		onClick = function()
			Net.send("TutorialAck", "skip")
		end,
		parent = frame,
	})

	StateController.changed:Connect(function(path)
		if path == "*" or path == "tutorial.step" or path == "tutorial.done" then
			refresh()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		accumulator = 0
		refresh()
	end)

	Players.LocalPlayer.CharacterRemoving:Connect(destroyGuide)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return TutorialController
