--!nonstrict
-- Peringatan pencurian untuk korban: toast + banner merah, tanda "!" berdenyut di atas Coop sendiri
-- (juga mengikuti atribut plot StealAlert). Di sini juga prompt server disembunyikan SECARA LOKAL:
-- StealPrompt di Coop sendiri / Coop ber-Shield / saat membawa telur, dan HatchPrompt di Coop orang lain.
-- Server tetap memvalidasi semuanya (docs/CHANGES.md #11).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local CarryController = require(script.Parent.CarryController)
local NotificationController = require(script.Parent.NotificationController)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags
local LocalPlayer = Players.LocalPlayer

local StealAlertController = {}

local BANNER_SECONDS = 4

local gui, banner, bannerLabel, billboard
local bannerToken = 0
local trackedModels = {} -- [model] = true
local bound = setmetatable({}, { __mode = "k" }) -- [prompt] = fungsi apakah-harus-disembunyikan

local function ownPlot(): Instance?
	local plots = workspace:FindFirstChild(Names.Plots)
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute(Attr.OwnerUserId) == LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

-- ===== Banner + tanda "!" =====

local function showBanner(text: string)
	bannerToken += 1
	local mine = bannerToken
	bannerLabel.Text = text
	banner.Visible = true
	task.delay(BANNER_SECONDS, function()
		if mine == bannerToken then
			banner.Visible = false
		end
	end)
end

local function buildBillboard()
	billboard = UIBuilder.create("BillboardGui", {
		Name = "StealAlertMark",
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(90, 90),
		StudsOffset = Vector3.new(0, 20, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
	})
	local mark = UIBuilder.create("TextLabel", {
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextScaled = true,
		TextColor3 = Theme.Colors.Brick,
		Text = "!",
		Parent = billboard,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.White }),
		},
	})
	TweenService:Create(
		mark,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromScale(1.25, 1.25) }
	):Play()
end

local function refreshMark()
	if not billboard then
		return
	end
	local plot = ownPlot()
	local floor = plot and plot:FindFirstChild(Names.PlotFloor)
	local active = plot ~= nil and floor ~= nil and plot:GetAttribute(Attr.StealAlert) == true
	if active then
		billboard.Adornee = floor
	end
	billboard.Enabled = active
end

-- ===== Prompt lokal =====

local function plotOfEgg(model: Instance): Instance?
	local eggs = model.Parent
	return eggs and eggs.Parent
end

local function shouldHideSteal(model: Instance): boolean
	local plot = plotOfEgg(model)
	if not plot then
		return true
	end
	local owner = plot:GetAttribute(Attr.OwnerUserId) or 0
	if owner == 0 or owner == LocalPlayer.UserId then
		return true
	end
	if (plot:GetAttribute(Attr.ShieldUntil) or 0) > 0 then
		return true
	end
	return CarryController.isCarrying()
end

local function shouldHideHatch(model: Instance): boolean
	local plot = plotOfEgg(model)
	if not plot then
		return false
	end
	local owner = plot:GetAttribute(Attr.OwnerUserId) or 0
	return owner ~= 0 and owner ~= LocalPlayer.UserId
end

-- Atur Enabled prompt. restore = true: kembalikan ke aktif bila tidak perlu disembunyikan
-- (HatchPrompt dikendalikan server saat telur siap, jadi tidak pernah dipaksa aktif).
local function applyPrompt(prompt: ProximityPrompt, getHide, restore: boolean)
	if not bound[prompt] then
		bound[prompt] = getHide
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			local hide = bound[prompt]
			if hide and hide() and prompt.Enabled then
				prompt.Enabled = false -- server mengaktifkan kembali: sembunyikan lagi
			end
		end)
	end
	if getHide() then
		if prompt.Enabled then
			prompt.Enabled = false
		end
	elseif restore and not prompt.Enabled then
		prompt.Enabled = true
	end
end

local function refreshModel(model: Instance)
	local primary = model:IsA("Model") and model.PrimaryPart
	if not primary then
		return
	end
	local steal = primary:FindFirstChild(Names.StealPrompt)
	if steal then
		applyPrompt(steal, function()
			return shouldHideSteal(model)
		end, true)
	end
	local hatch = primary:FindFirstChild(Names.HatchPrompt)
	if hatch then
		applyPrompt(hatch, function()
			return shouldHideHatch(model)
		end, false)
	end
end

local function trackModel(model: Instance)
	if trackedModels[model] then
		return
	end
	trackedModels[model] = true
	model.DescendantAdded:Connect(function()
		refreshModel(model)
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent then
			refreshModel(model)
		else
			trackedModels[model] = nil
		end
	end)
	refreshModel(model)
end

local function refreshAllModels()
	for model in trackedModels do
		refreshModel(model)
	end
end

local function watchPlot(plot: Instance)
	for _, attribute in { Attr.OwnerUserId, Attr.ShieldUntil } do
		plot:GetAttributeChangedSignal(attribute):Connect(function()
			refreshAllModels()
			refreshMark()
		end)
	end
	plot:GetAttributeChangedSignal(Attr.StealAlert):Connect(refreshMark)
end

function StealAlertController.Start()
	Net.connect("StealAlert", function(payload)
		if type(payload) ~= "table" then
			return
		end
		local name = tostring(payload.thiefName or "Someone")
		NotificationController.push(`{name} is stealing your egg!`, "error")
		showBanner(`{name} is stealing your {payload.name or "egg"}!`)
	end)

	CarryController.changed:Connect(refreshAllModels)

	CollectionService:GetInstanceAddedSignal(Tags.PlacedEgg):Connect(trackModel)
	for _, model in CollectionService:GetTagged(Tags.PlacedEgg) do
		trackModel(model)
	end

	task.spawn(function()
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		gui = UIBuilder.create("ScreenGui", {
			Name = "StealAlert",
			ResetOnSpawn = false,
			DisplayOrder = 40,
		})
		banner = UIBuilder.create("Frame", {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 150),
			Size = UDim2.fromOffset(380, 52),
			BackgroundColor3 = Theme.Colors.Brick,
			Visible = false,
			Parent = gui,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				UIBuilder.create("UIStroke", { Thickness = 3, Color = Theme.Colors.Brown }),
			},
		})
		bannerLabel = UIBuilder.create("TextLabel", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextScaled = true,
			TextColor3 = Theme.Colors.White,
			Text = "",
			Parent = banner,
		})
		gui.Parent = playerGui

		buildBillboard()
		billboard.Parent = playerGui

		local plots = workspace:WaitForChild(Names.Plots)
		for _, plot in plots:GetChildren() do
			watchPlot(plot)
		end
		plots.ChildAdded:Connect(watchPlot)
		refreshMark()
		refreshAllModels()
	end)
end

return StealAlertController
