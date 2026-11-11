--!nonstrict
-- Isi modal "Pet Index": tab World/Limited, pemilih zona (12), kartu 8 spesies per zona,
-- header "Unlocked: n/96" dan tombol CLAIM ALL (n)!. Diperbarui langsung dari StateController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Creatures = require(Shared.Config.Creatures)
local Zones = require(Shared.Config.Zones)
local IndexMath = require(Shared.Logic.IndexMath)
local ModelFactory = require(Shared.ModelFactory)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local IndexPanel = {}

local CARD_W, CARD_H = 160, 176
local SILHOUETTE = Color3.fromRGB(18, 18, 24)

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextScaled = true,
		ZIndex = 4,
	}
	for k, v in props do
		base[k] = v
	end
	return UIBuilder.create("TextLabel", base)
end

-- Viewport berisi model makhluk (atau siluet hitam bila silhouette = true).
local function makeViewport(parent: Instance, creature, silhouette: boolean)
	local viewport = UIBuilder.create("ViewportFrame", {
		Name = "Viewport",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 70),
		BackgroundColor3 = if silhouette
			then Color3.fromRGB(70, 60, 55)
			else ModelFactory.rarityColor(creature.rarity):Lerp(Theme.Colors.Cream, 0.7),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = { UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }) },
	})
	local model = ModelFactory.makeCreature(creature, creature.baseKg, nil)
	if silhouette then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = SILHOUETTE
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	model.Parent = viewport
	model:PivotTo(CFrame.Angles(0, math.rad(-35), 0))
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local size = model:GetExtentsSize()
	local radius = math.max(size.X, size.Y, size.Z)
	local distance = (radius * 0.5) / math.tan(math.rad(20)) * 1.5 + radius * 0.5
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.35, distance), Vector3.zero)
	return viewport
end

local function buildCard(
	creature,
	found: boolean,
	claimed: boolean,
	parent: Instance,
	order: number
)
	local rarityColor = ModelFactory.rarityColor(creature.rarity)
	local card = UIBuilder.create("Frame", {
		Name = "Card_" .. creature.id,
		LayoutOrder = order,
		BackgroundColor3 = if found
			then Color3.fromRGB(255, 238, 200)
			else Color3.fromRGB(226, 212, 186),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UIBuilder.create("UIStroke", {
				Thickness = 2,
				Color = if found then rarityColor else Theme.Colors.Brown,
				Transparency = if found then 0 else 0.5,
			}),
		},
	})
	makeViewport(card, creature, not found)

	label({
		Name = "Name",
		Position = UDim2.fromOffset(6, 80),
		Size = UDim2.new(1, -12, 0, 20),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if found then rarityColor else Theme.Colors.Brown,
		Text = if found then creature.name else "???",
		Parent = card,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
		},
	})
	if not found then
		label({
			Name = "Hint",
			Position = UDim2.fromOffset(6, 106),
			Size = UDim2.new(1, -12, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "Not discovered",
			Parent = card,
		})
		return
	end

	label({
		Name = "Income",
		Position = UDim2.fromOffset(6, 101),
		Size = UDim2.new(1, -12, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(60, 140, 70),
		Text = NumberFormat.fmtRate(creature.baseIncome),
		Parent = card,
	})
	local cash, speed = IndexMath.rewards(creature.id)
	label({
		Name = "Reward",
		Position = UDim2.fromOffset(6, 118),
		Size = UDim2.new(1, -12, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = `{NumberFormat.fmtMoney(cash)} + {NumberFormat.fmt(speed)} speed`,
		Parent = card,
	})
	if claimed then
		label({
			Name = "Claimed",
			Position = UDim2.new(0, 8, 1, -34),
			Size = UDim2.new(1, -16, 0, 28),
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(60, 140, 70),
			Text = "CLAIMED!",
			Parent = card,
		})
	else
		local button = Button.new({
			name = "Claim",
			text = "CLAIM!",
			color = Theme.Colors.Mint,
			position = UDim2.new(0, 8, 1, -36),
			size = UDim2.new(1, -16, 0, 30),
			textSize = 18,
			onClick = function()
				Net.send("ClaimIndex", creature.id)
			end,
			parent = card,
		})
		button.ZIndex = 5
	end
end

local function buildLimitedCard(name: string, parent: Instance, order: number)
	local card = UIBuilder.create("Frame", {
		Name = "Limited_" .. order,
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(226, 212, 186),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UIBuilder.create("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.Brown,
				Transparency = 0.5,
			}),
		},
	})
	label({
		Name = "Mark",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 70),
		Font = Theme.Fonts.Title,
		TextColor3 = Color3.fromRGB(150, 130, 110),
		Text = "?",
		Parent = card,
	})
	label({
		Name = "Name",
		Position = UDim2.fromOffset(6, 80),
		Size = UDim2.new(1, -12, 0, 20),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = name,
		Parent = card,
	})
	label({
		Name = "Soon",
		Position = UDim2.fromOffset(6, 106),
		Size = UDim2.new(1, -12, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Coming soon",
		Parent = card,
	})
end

-- container: frame konten dari ModalController; state: StateController. Mengembalikan fungsi pembersih.
function IndexPanel.build(container: Frame, state)
	local tab = "World"
	local zone = 1
	local refresh

	local header = label({
		Name = "Header",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0.4, 0, 0, 32),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = container,
	})
	local claimAll = Button.new({
		name = "ClaimAll",
		text = "CLAIM ALL!",
		color = Theme.Colors.Mint,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -4, 0, 0),
		size = UDim2.fromOffset(190, 34),
		textSize = 18,
		onClick = function()
			Net.send("ClaimIndexAll")
		end,
		parent = container,
	})
	claimAll.ZIndex = 4

	local tabs = {}
	for i, name in { "World", "Limited" } do
		tabs[name] = Button.new({
			name = "Tab_" .. name,
			text = name,
			position = UDim2.fromOffset(4 + (i - 1) * 110, 38),
			size = UDim2.fromOffset(104, 30),
			textSize = 18,
			parent = container,
		})
		tabs[name].ZIndex = 4
	end

	local zoneBar = UIBuilder.create("ScrollingFrame", {
		Name = "ZoneBar",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		},
	})
	local zoneButtons = {}
	for i = 1, Zones.count do
		zoneButtons[i] = Button.new({
			name = "Zone_" .. i,
			text = "",
			layoutOrder = i,
			size = UDim2.fromOffset(130, 34),
			textSize = 14,
			onClick = function()
				zone = i
				refresh()
			end,
			parent = zoneBar,
		})
		zoneButtons[i].ZIndex = 4
	end

	local grid = UIBuilder.create("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 1, -124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIGridLayout", {
				CellSize = UDim2.fromOffset(CARD_W, CARD_H),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})

	function refresh()
		local found = state.get("index.found") or {}
		local claimed = state.get("index.claimed") or {}
		local unclaimed = IndexMath.unclaimedCount(found, claimed)
		header.Text = `Unlocked: {IndexMath.foundCount(found)}/{IndexMath.totalSpecies()}`
		claimAll.Text = `CLAIM ALL ({unclaimed})!`
		claimAll.Visible = tab == "World"
		Button.setDisabled(claimAll, unclaimed == 0)

		for name, button in tabs do
			button.BackgroundColor3 = if name == tab
				then Theme.Colors.Yolk
				else Color3.fromRGB(150, 130, 110)
		end
		zoneBar.Visible = tab == "World"
		grid.Position = if tab == "World" then UDim2.fromOffset(0, 124) else UDim2.fromOffset(0, 74)
		grid.Size = if tab == "World" then UDim2.new(1, 0, 1, -124) else UDim2.new(1, 0, 1, -74)

		local scroll = grid.CanvasPosition
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		if tab == "World" then
			for i = 1, Zones.count do
				local n, total = IndexMath.zoneProgress(found, i)
				zoneButtons[i].Text = `{i}. {Zones.get(i).name} {n}/{total}`
				zoneButtons[i].BackgroundColor3 = if i == zone
					then Theme.Colors.Yolk
					else (if n == total
						then Theme.Colors.Mint
						else Color3.fromRGB(150, 130, 110))
			end
			for i, creature in Creatures.byZone[zone] do
				buildCard(
					creature,
					found[creature.id] == true,
					claimed[creature.id] == true,
					grid,
					i
				)
			end
		else
			for i, name in CollectionConfig.index.limited do
				buildLimitedCard(name, grid, i)
			end
		end
		grid.CanvasPosition = scroll
	end
	for name, button in tabs do
		button.Activated:Connect(function()
			tab = name
			refresh()
		end)
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*" or string.sub(path, 1, 6) == "index."
		if relevant and not dirty then
			dirty = true
			task.defer(function()
				dirty = false
				if alive then
					refresh()
				end
			end)
		end
	end)
	refresh()

	return function()
		alive = false
		connection:Disconnect()
	end
end

return IndexPanel
