--!nonstrict
-- Isi modal "Shop": tab Featured / Gamepasses / Cash / Potions / Trails. Kartu berisi nama, deskripsi,
-- harga "R$ n" dan tombol Buy. Id 0 (belum dibuat di Creator Dashboard) = tombol "Coming soon" nonaktif;
-- tombol Buy tidak pernah memanggil Prompt* dengan id 0.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local MonetizationMath = require(Shared.Logic.MonetizationMath)
local NumberFormat = require(Shared.Logic.NumberFormat)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local ShopPanel = {}

local CARD_SIZE = UDim2.fromOffset(200, 156)
local TAB_HEIGHT = 36
local TABS = { "Featured", "Gamepasses", "Cash", "Potions", "Trails" }

local POTION_KINDS = { potion = true, shield = true, wheel = true, growAll = true }

local function text(parent: Instance, props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextScaled = true,
		ZIndex = 4,
		Parent = parent,
	}
	for k, v in props do
		base[k] = v
	end
	return UIBuilder.create("TextLabel", base)
end

local function promptPurchase(item)
	if item.id == 0 then
		return
	end
	local player = Players.LocalPlayer
	local ok, err = pcall(function()
		if item.kind == "gamepass" then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end)
	if not ok then
		warn("[ShopPanel] prompt gagal:", err)
	end
end

local function isGamepassOwned(state, key: string): boolean
	if state.get(`ownedPasses.{key}`) == true then
		return true
	end
	return key == "equip3" and state.get("passes.equip3") == true
end

-- Item kartu dari config. kind: "gamepass" | produk.kind.
local function gamepassItem(state, pass)
	return {
		key = pass.key,
		kind = "gamepass",
		name = pass.name,
		desc = pass.desc,
		price = pass.price,
		id = pass.id,
		owned = isGamepassOwned(state, pass.key),
	}
end

local function productItem(state, product)
	local desc = product.desc
	if product.kind == "cash" then
		local income = state.get("lastIncomePerSec") or 0
		desc =
			`{NumberFormat.fmtMoney(MonetizationMath.cashPackAmount(income, product.arg))} now. {product.desc}`
	end
	return {
		key = product.key,
		kind = product.kind,
		name = product.name,
		desc = desc,
		price = product.price,
		id = product.id,
		owned = false,
	}
end

local function itemsForTab(tab: string, state)
	local items = {}
	if tab == "Featured" then
		for _, entry in MonetizationConfig.featured do
			if entry.type == "gamepass" then
				local pass = MonetizationConfig.getGamepass(entry.key)
				if pass then
					table.insert(items, gamepassItem(state, pass))
				end
			else
				local product = MonetizationConfig.getProduct(entry.key)
				if product then
					table.insert(items, productItem(state, product))
				end
			end
		end
	elseif tab == "Gamepasses" then
		for _, pass in MonetizationConfig.gamepasses do
			table.insert(items, gamepassItem(state, pass))
		end
	else
		for _, product in MonetizationConfig.products do
			local kind = product.kind
			local show = (tab == "Cash" and kind == "cash")
				or (tab == "Potions" and POTION_KINDS[kind] == true)
				or (tab == "Trails" and kind == "trail")
			if show then
				table.insert(items, productItem(state, product))
			end
		end
	end
	return items
end

local function buildCard(item, parent: Instance, order: number)
	local card = UIBuilder.create("Frame", {
		Name = "Card_" .. item.key,
		LayoutOrder = order,
		Size = CARD_SIZE,
		BackgroundColor3 = Color3.fromRGB(246, 232, 204),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.YolkDark }),
		},
	})
	text(card, {
		Name = "Name",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 24),
		Font = Theme.Fonts.Title,
		Text = item.name,
	})
	text(card, {
		Name = "Desc",
		Position = UDim2.fromOffset(8, 32),
		Size = UDim2.new(1, -16, 0, 48),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.desc,
		[UIBuilder.Children] = {
			UIBuilder.create("UITextSizeConstraint", { MaxTextSize = 15 }),
		},
	})
	text(card, {
		Name = "Price",
		Position = UDim2.fromOffset(8, 84),
		Size = UDim2.new(1, -16, 0, 20),
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.YolkDark,
		Text = `R$ {item.price}`,
	})

	local label, color, disabled
	if item.owned then
		label, color, disabled = "Owned", Theme.Colors.Mint, true
	elseif item.id == 0 then
		label, color, disabled = "Coming soon", Color3.fromRGB(150, 130, 110), true
	else
		label, color, disabled = "Buy", Theme.Colors.Mint, false
	end
	local button = Button.new({
		name = "Action",
		text = label,
		color = color,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		size = UDim2.new(1, -16, 0, 36),
		textSize = 16,
		onClick = function()
			promptPurchase(item)
		end,
		parent = card,
	})
	button.ZIndex = 5
	if disabled then
		Button.setDisabled(button, true)
	end
end

-- container: frame konten dari ModalController; state: StateController;
-- options.openTrails: dipanggil oleh tombol "Open Trails Shop (cash)" di tab Trails.
function ShopPanel.build(container: Frame, state, options)
	options = options or {}
	local activeTab = "Featured"

	local tabRow = UIBuilder.create("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		BackgroundTransparency = 1,
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
	local tabButtons = {}

	local list = UIBuilder.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, TAB_HEIGHT + 8),
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 8)),
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
				CellSize = CARD_SIZE,
				CellPadding = UDim2.fromOffset(10, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		},
	})

	local function refresh()
		local scroll = list.CanvasPosition
		for _, child in list:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == activeTab
				then Theme.Colors.Yolk
				else Color3.fromRGB(150, 130, 110)
		end
		local order = 0
		if activeTab == "Trails" and options.openTrails then
			order += 1
			Button.new({
				name = "OpenTrails",
				text = "Open Trails Shop (cash)",
				color = Theme.Colors.Mint,
				layoutOrder = order,
				textSize = 15,
				onClick = options.openTrails,
				parent = list,
			})
		end
		for _, item in itemsForTab(activeTab, state) do
			order += 1
			buildCard(item, list, order)
		end
		list.CanvasPosition = scroll
	end

	for i, name in TABS do
		tabButtons[name] = Button.new({
			name = "Tab_" .. name,
			text = name,
			layoutOrder = i,
			size = UDim2.fromOffset(110, TAB_HEIGHT),
			textSize = 14,
			onClick = function()
				activeTab = name
				refresh()
			end,
			parent = tabRow,
		})
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*"
			or string.sub(path, 1, 11) == "ownedPasses"
			or string.sub(path, 1, 6) == "passes"
			or path == "lastIncomePerSec"
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

return ShopPanel
