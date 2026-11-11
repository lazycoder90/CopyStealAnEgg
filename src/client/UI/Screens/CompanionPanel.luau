--!nonstrict
-- Isi modal "Grow Your Bud": header stage, 4 titik progres, daftar quest stage sekarang (bar "n/target"),
-- tombol CLAIM, dan footer. Diperbarui langsung dari StateController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventsConfig = require(Shared.Config.EventsConfig)
local CompanionMath = require(Shared.Logic.CompanionMath)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local CompanionPanel = {}

local GRAY = Color3.fromRGB(205, 190, 165)
local TRACK = Color3.fromRGB(232, 217, 190)

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextSize = 18,
		ZIndex = 4,
	}
	for k, v in props do
		base[k] = v
	end
	return UIBuilder.create("TextLabel", base)
end

-- container: frame konten dari ModalController; state: StateController. Mengembalikan fungsi pembersih.
function CompanionPanel.build(container: Frame, state)
	local header = label({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.Fonts.Title,
		TextSize = 26,
		Text = "",
		Parent = container,
	})

	local dotsRow = UIBuilder.create("Frame", {
		Name = "Dots",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(4 * 28 + 3 * 18, 28),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 18),
			}),
		},
	})
	local dots = {}
	for i = 1, CompanionMath.maxStage do
		dots[i] = UIBuilder.create("Frame", {
			Name = "Dot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = GRAY,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = dotsRow,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
			},
		})
	end

	local reward = label({
		Name = "Reward",
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Parent = container,
	})

	local list = UIBuilder.create("Frame", {
		Name = "Quests",
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 1, -112 - 96),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		},
	})

	local claim = Button.new({
		name = "Claim",
		text = "CLAIM",
		color = Theme.Colors.Mint,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -32),
		size = UDim2.fromOffset(220, 50),
		onClick = function()
			Net.send("ClaimCompanionStage")
		end,
		parent = container,
	})
	claim.ZIndex = 4

	label({
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 16,
		TextTransparency = 0.25,
		Text = "Your Bud progress is saved",
		Parent = container,
	})

	local function buildQuest(quest, progress, order)
		local n = CompanionMath.count(progress, quest)
		local row = UIBuilder.create("Frame", {
			Name = "Quest_" .. quest.key,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Color3.fromRGB(246, 232, 204),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = list,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			},
		})
		label({
			Name = "Text",
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = quest.text,
			Parent = row,
		})
		local track = UIBuilder.create("Frame", {
			Name = "Track",
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 16),
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = row,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			},
		})
		UIBuilder.create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(n / quest.target, 1),
			BackgroundColor3 = if n >= quest.target then Theme.Colors.Mint else Theme.Colors.Yolk,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = track,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			},
		})
		label({
			Name = "Count",
			Size = UDim2.fromScale(1, 1),
			Font = Theme.Fonts.Title,
			TextSize = 14,
			Text = `{n}/{quest.target}`,
			ZIndex = 7,
			Parent = track,
		})
	end

	local function refresh()
		local companion = state.get("companion") or {}
		local stage = CompanionMath.clampStage(companion.stage)
		local def = EventsConfig.stages[stage]
		header.Text = `Stage {stage}: {def.name}`
		reward.Text = "Reward: " .. def.reward
		for i, dot in dots do
			local reached = i <= stage or CompanionMath.isClaimed(companion, i)
			dot.BackgroundColor3 = if reached then Theme.Colors.Yolk else GRAY
		end

		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, quest in CompanionMath.questsFor(stage) do
			buildQuest(quest, companion.progress, i)
		end

		local done = CompanionMath.isClaimed(companion, stage)
		local can = CompanionMath.canClaim(companion)
		claim.Text = if done then "Fully grown!" else "CLAIM"
		Button.setDisabled(claim, not can)
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		if path == "*" or path == "companion" or string.sub(path, 1, 10) == "companion." then
			if not dirty then
				dirty = true
				task.defer(function()
					dirty = false
					if alive then
						refresh()
					end
				end)
			end
		end
	end)
	refresh()

	return function()
		alive = false
		connection:Disconnect()
	end
end

return CompanionPanel
