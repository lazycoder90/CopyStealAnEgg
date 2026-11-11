--!nonstrict
-- Frying Pan: mendengarkan Tool.Activated (tap di mobile juga lewat sini), memutar animasi ayun lokal,
-- mengirim SwingPan ke server, dan menegakkan cooldown 1.2 detik di klien (server tetap memvalidasi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local PvpRules = require(Shared.Logic.PvpRules)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local LocalPlayer = Players.LocalPlayer

local PanController = {}

local lastSwing = 0
local hooked = setmetatable({}, { __mode = "k" }) -- [tool] = true
local watched = setmetatable({}, { __mode = "k" }) -- [container] = true
local ring, fill

local function showCooldown()
	if not (ring and fill) then
		return
	end
	ring.Visible = true
	fill.Size = UDim2.fromScale(0, 1)
	local tween = TweenService:Create(
		fill,
		TweenInfo.new(PvpRules.panCooldown, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	tween.Completed:Connect(function()
		if os.clock() - lastSwing >= PvpRules.panCooldown - 0.05 then
			ring.Visible = false
		end
	end)
	tween:Play()
end

-- Ayun: putar grip tool ke depan lalu kembali.
local function animate(tool: Tool)
	local base = tool.Grip
	task.spawn(function()
		local out = TweenService:Create(
			tool,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Grip = base * CFrame.Angles(math.rad(-85), 0, 0) }
		)
		out:Play()
		out.Completed:Wait()
		TweenService:Create(
			tool,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Grip = base }
		):Play()
	end)
end

local function swing(tool: Tool)
	local now = os.clock()
	if now - lastSwing < PvpRules.panCooldown then
		return
	end
	lastSwing = now
	Net.send("SwingPan")
	animate(tool)
	showCooldown()
end

local function hookTool(child: Instance)
	if child:IsA("Tool") and child.Name == PvpRules.panToolName and not hooked[child] then
		hooked[child] = true
		child.Activated:Connect(function()
			swing(child)
		end)
	end
end

local function watch(container: Instance)
	if watched[container] then
		return
	end
	watched[container] = true
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

local function onCharacter(character: Model)
	watch(character)
	task.spawn(function()
		local backpack = LocalPlayer:WaitForChild("Backpack", 10)
		if backpack then
			watch(backpack)
		end
	end)
end

function PanController.Start()
	LocalPlayer.CharacterAdded:Connect(onCharacter)
	if LocalPlayer.Character then
		onCharacter(LocalPlayer.Character)
	end

	task.spawn(function()
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		local gui = UIBuilder.create("ScreenGui", {
			Name = "PanCooldown",
			ResetOnSpawn = false,
			DisplayOrder = 15,
		})
		ring = UIBuilder.create("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -140),
			Size = UDim2.fromOffset(120, 8),
			BackgroundColor3 = Theme.Colors.Brown,
			BackgroundTransparency = 0.4,
			Visible = false,
			Parent = gui,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			},
		})
		fill = UIBuilder.create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Colors.Yolk,
			BorderSizePixel = 0,
			Parent = ring,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			},
		})
		gui.Parent = playerGui
	end)
end

return PanController
