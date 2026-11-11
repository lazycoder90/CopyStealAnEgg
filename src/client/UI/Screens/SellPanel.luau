--!nonstrict
-- Isi modal "Sell": tab Eggs/Pets, urutan Weight/Value, Select All, grid kartu, total, tombol Sell,
-- dan dialog konfirmasi bila ada item rarity >= Mythic. Total di klien hanya tampilan; server menghitung ulang.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Rarities = require(Shared.Config.Rarities)
local SellConfig = require(Shared.Config.SellConfig)
local SellMath = require(Shared.Logic.SellMath)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local SellPanel = {}

local GREY = Color3.fromRGB(150, 130, 110)
local CARD_W, CARD_H = 138, 104

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		ZIndex = 4,
	}
	for k, v in props do
		base[k] = v
	end
	return UIBuilder.create("TextLabel", base)
end

local function rarityColor(rarity: number): Color3
	local rgb = Rarities.get(rarity).rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Tombol pil sederhana yang warnanya diatur langsung (tanpa tween warna milik Button).
local function pill(props)
	return UIBuilder.create("TextButton", {
		Name = props.name,
		AutoButtonColor = false,
		AnchorPoint = props.anchorPoint or Vector2.zero,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = props.color or GREY,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Title,
		TextSize = props.textSize or 18,
		TextColor3 = Theme.Colors.White,
		Text = props.text,
		ZIndex = 4,
		Parent = props.parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
			UIBuilder.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
end

-- container: frame konten modal; state: StateController. Mengembalikan fungsi pembersih.
function SellPanel.build(container: Frame, state)
	local tab = "eggs"
	local sortBy = "value"
	local ascending = false
	local selected = {}
	local items = {}

	-- Baris atas: tab.
	local tabEggs, tabPets
	local function styleTabs()
		tabEggs.BackgroundColor3 = if tab == "eggs" then Theme.Colors.Yolk else GREY
		tabPets.BackgroundColor3 = if tab == "pets" then Theme.Colors.Yolk else GREY
	end

	local refresh
	local function setTab(name: string)
		if tab ~= name then
			tab = name
			selected = {}
		end
		styleTabs()
		refresh()
	end
	tabEggs = pill({
		name = "TabEggs",
		text = "Eggs",
		position = UDim2.fromOffset(0, 0),
		size = UDim2.fromOffset(110, 38),
		textSize = 18,
		onClick = function()
			setTab("eggs")
		end,
		parent = container,
	})
	tabPets = pill({
		name = "TabPets",
		text = "Pets",
		position = UDim2.fromOffset(118, 0),
		size = UDim2.fromOffset(110, 38),
		textSize = 18,
		onClick = function()
			setTab("pets")
		end,
		parent = container,
	})

	-- Baris urutan + Select All.
	label({
		Name = "SortLabel",
		Position = UDim2.fromOffset(240, 4),
		Size = UDim2.fromOffset(70, 30),
		Font = Theme.Fonts.Title,
		Text = "Sort By:",
		Parent = container,
	})
	local sortWeight = pill({
		name = "SortWeight",
		text = "Weight",
		position = UDim2.fromOffset(314, 0),
		size = UDim2.fromOffset(104, 38),
		textSize = 16,
		onClick = function()
			if sortBy == "weight" then
				ascending = not ascending
			else
				sortBy, ascending = "weight", false
			end
			refresh()
		end,
		parent = container,
	})
	local sortValue = pill({
		name = "SortValue",
		text = "Value",
		position = UDim2.fromOffset(424, 0),
		size = UDim2.fromOffset(104, 38),
		textSize = 16,
		onClick = function()
			if sortBy == "value" then
				ascending = not ascending
			else
				sortBy, ascending = "value", false
			end
			refresh()
		end,
		parent = container,
	})

	local selectAll = pill({
		name = "SelectAll",
		text = "[ ] Select All",
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		size = UDim2.fromOffset(150, 38),
		textSize = 16,
		color = GREY,
		onClick = function()
			local allSelected = #items > 0
			for _, item in items do
				if not selected[item.uid] then
					allSelected = false
					break
				end
			end
			selected = {}
			if not allSelected then
				for _, item in items do
					selected[item.uid] = true
				end
			end
			refresh()
		end,
		parent = container,
	})

	local grid = UIBuilder.create("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -106),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIGridLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				CellSize = UDim2.fromOffset(CARD_W, CARD_H),
				CellPadding = UDim2.fromOffset(8, 8),
			}),
			UIBuilder.create(
				"UIPadding",
				{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }
			),
		},
	})
	local empty = label({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Nothing to sell here.",
		Parent = container,
	})

	-- Footer.
	local totalLabel = label({
		Name = "Total",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, 0, 0, 44),
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Brown,
		Text = "Total Value: $0",
		Parent = container,
	})

	-- Dialog konfirmasi (frame kecil di dalam panel).
	local confirm = UIBuilder.create("Frame", {
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 150),
		BackgroundColor3 = Theme.Colors.Cream,
		Visible = false,
		ZIndex = 10,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UIStroke", { Thickness = 3, Color = Theme.Colors.Brown }),
		},
	})
	local confirmText = label({
		Name = "Text",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 54),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		Text = "",
		ZIndex = 11,
		Parent = confirm,
	})

	local function selectedUids(): { string }
		local uids = {}
		for _, item in items do
			if selected[item.uid] then
				table.insert(uids, item.uid)
			end
		end
		return uids
	end
	local function send()
		local uids = selectedUids()
		if #uids == 0 then
			return
		end
		Net.send("SellItems", tab, uids)
		selected = {}
		refresh()
	end

	local yes = Button.new({
		name = "ConfirmYes",
		text = "Sell",
		color = Theme.Colors.Brick,
		position = UDim2.fromOffset(20, 84),
		size = UDim2.fromOffset(120, 44),
		onClick = function()
			confirm.Visible = false
			send()
		end,
		parent = confirm,
	})
	local no = Button.new({
		name = "ConfirmNo",
		text = "Cancel",
		color = GREY,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -20, 0, 84),
		size = UDim2.fromOffset(120, 44),
		onClick = function()
			confirm.Visible = false
		end,
		parent = confirm,
	})
	yes.ZIndex, no.ZIndex = 11, 11

	local sellButton = Button.new({
		name = "Sell",
		text = "Sell",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.fromScale(1, 1),
		size = UDim2.fromOffset(170, 46),
		onClick = function()
			local _, count = SellMath.selectedTotals(items, selected)
			if count == 0 then
				return
			end
			if SellMath.hasValuable(items, selected, SellConfig.confirmMinRarity) then
				confirmText.Text = `Sell {count} valuable items?`
				confirm.Visible = true
			else
				send()
			end
		end,
		parent = container,
	})
	sellButton.ZIndex = 4

	local function buildCard(item, order: number)
		local isSelected = selected[item.uid] == true
		local card = UIBuilder.create("TextButton", {
			Name = "Card_" .. item.uid,
			LayoutOrder = order,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(200, 240, 200)
				else Color3.fromRGB(246, 232, 204),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = grid,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				UIBuilder.create("UIStroke", {
					Thickness = if isSelected then 3 else 1,
					Color = if isSelected then Theme.Colors.Mint else Theme.Colors.Brown,
				}),
			},
		})
		label({
			Name = "Name",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 22),
			Font = Theme.Fonts.Title,
			TextColor3 = rarityColor(item.rarity),
			Text = item.name,
			Parent = card,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
			},
		})
		label({
			Name = "Weight",
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -12, 0, 18),
			Text = string.format("%.1f kg", item.kg),
			Parent = card,
		})
		label({
			Name = "Rate",
			Position = UDim2.fromOffset(6, 48),
			Size = UDim2.new(1, -12, 0, 18),
			Text = NumberFormat.fmtRate(item.income),
			Parent = card,
		})
		label({
			Name = "Price",
			Position = UDim2.fromOffset(6, 72),
			Size = UDim2.new(1, -12, 0, 24),
			Font = Theme.Fonts.Title,
			TextColor3 = Color3.fromRGB(40, 140, 60),
			Text = NumberFormat.fmtMoney(item.value),
			Parent = card,
		})
		card.Activated:Connect(function()
			selected[item.uid] = if selected[item.uid] then nil else true
			refresh()
		end)
	end

	refresh = function()
		local collection = state.get(tab)
		items = SellMath.list(tab, collection)
		SellMath.sort(items, sortBy, ascending)

		-- Buang pilihan yang sudah tidak ada.
		local present = {}
		for _, item in items do
			present[item.uid] = true
		end
		for uid in selected do
			if not present[uid] then
				selected[uid] = nil
			end
		end

		local scroll = grid.CanvasPosition
		for _, child in grid:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for i, item in items do
			buildCard(item, i)
		end
		grid.CanvasPosition = scroll
		empty.Visible = #items == 0

		local sum, count = SellMath.selectedTotals(items, selected)
		totalLabel.Text = "Total Value: " .. NumberFormat.fmtMoney(sum)
		sellButton.Text = if count > 0 then `Sell ({count})` else "Sell"
		Button.setDisabled(sellButton, count == 0)

		local allSelected = #items > 0 and count == #items
		selectAll.Text = if allSelected then "[x] Select All" else "[ ] Select All"
		sortWeight.BackgroundColor3 = if sortBy == "weight" then Theme.Colors.Mint else GREY
		sortValue.BackgroundColor3 = if sortBy == "value" then Theme.Colors.Mint else GREY
		sortWeight.Text = if sortBy == "weight"
			then (if ascending then "Weight: Low" else "Weight: High")
			else "Weight"
		sortValue.Text = if sortBy == "value"
			then (if ascending then "Value: Low" else "Value: High")
			else "Value"
	end
	styleTabs()
	refresh()

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*"
			or path == "eggs"
			or path == "pets"
			or (
				(string.sub(path, 1, 5) == "eggs." or string.sub(path, 1, 5) == "pets.")
				and string.sub(path, -9) ~= ".progress"
			)
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

	return function()
		alive = false
		connection:Disconnect()
	end
end

return SellPanel
