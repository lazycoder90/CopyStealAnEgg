--!nonstrict
-- Isi modal "Astronomer Tilly": saldo Stardust, daftar penawaran (nama, deskripsi, harga, tombol Buy).
-- Untuk "orbital" Buy membuka daftar telur placed milik sendiri (tanpa Orbital) untuk dipilih.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)
local MutationLogic = require(Shared.Logic.MutationLogic)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local TillyTrade = {}

local ROW_BG = Color3.fromRGB(246, 232, 204)
local PURPLE = Color3.fromRGB(150, 110, 230)

local function label(parent: Instance, props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = parent,
	}
	for k, v in props do
		base[k] = v
	end
	return UIBuilder.create("TextLabel", base)
end

local function row(parent: Instance, order: number, height: number)
	return UIBuilder.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = ROW_BG,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		},
	})
end

-- Telur placed milik sendiri yang masih bisa menerima Orbital.
local function eligibleEggs(state)
	local out = {}
	local eggs = state.get("eggs") or {}
	for uid, egg in eggs do
		if egg.loc == "placed" and MutationLogic.canAdd(egg.muts or {}, "Orbital") then
			table.insert(out, { uid = uid, egg = egg })
		end
	end
	table.sort(out, function(a, b)
		return a.uid < b.uid
	end)
	return out
end

function TillyTrade.build(container: Frame, state)
	local choosing = false
	local refresh

	local header = label(container, {
		Name = "Balance",
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Fonts.Title,
		TextColor3 = PURPLE,
		Text = "Stardust: 0",
	})
	local list = UIBuilder.create("ScrollingFrame", {
		Name = "Offers",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		},
	})

	local function addOfferRow(offer, order: number, stardust: number)
		local frame = row(list, order, 64)
		label(frame, {
			Name = "Name",
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Font = Theme.Fonts.Title,
			Text = offer.name,
		})
		label(frame, {
			Name = "Desc",
			Position = UDim2.fromOffset(10, 34),
			Size = UDim2.new(1, -150, 0, 20),
			Text = `{offer.desc} - {offer.price} Stardust`,
		})
		local buy = Button.new({
			name = "Buy",
			text = if offer.needsEgg and choosing then "Cancel" else `Buy {offer.price}`,
			color = if offer.needsEgg and choosing then Theme.Colors.Brick else Theme.Colors.Mint,
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			size = UDim2.fromOffset(120, 40),
			textSize = 18,
			parent = frame,
			onClick = function()
				if offer.needsEgg then
					choosing = not choosing
					refresh()
				else
					Net.send("TradeStardust", offer.id)
				end
			end,
		})
		buy.ZIndex = 5
		Button.setDisabled(buy, stardust < offer.price)
	end

	local function addEggRows(startOrder: number)
		local eggs = eligibleEggs(state)
		if #eggs == 0 then
			local empty = row(list, startOrder, 34)
			label(empty, {
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -20, 1, -8),
				Text = "No eligible placed eggs. Place an egg in your Coop first.",
			})
			return
		end
		for i, item in eggs do
			local species = Creatures.get(item.egg.id)
			local rgb = Rarities.get(species.rarity).rgb
			local frame = row(list, startOrder + i - 1, 48)
			label(frame, {
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -140, 0, 22),
				Font = Theme.Fonts.Title,
				TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
				Text = species.name,
				[UIBuilder.Children] = {
					UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
				},
			})
			local muts = item.egg.muts or {}
			label(frame, {
				Position = UDim2.fromOffset(10, 27),
				Size = UDim2.new(1, -140, 0, 16),
				Text = if #muts > 0 then MutationLogic.format(muts) else "No mutations",
			})
			local apply = Button.new({
				name = "Apply",
				text = "Apply",
				color = PURPLE,
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -8, 0.5, 0),
				size = UDim2.fromOffset(100, 34),
				textSize = 16,
				parent = frame,
				onClick = function()
					choosing = false
					Net.send("TradeStardust", StarwhaleConfig.offerById.orbital.id, item.uid)
				end,
			})
			apply.ZIndex = 5
		end
	end

	refresh = function()
		local scroll = list.CanvasPosition
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local stardust = state.get("stardust") or 0
		header.Text = `Stardust: {stardust}`
		local order = 0
		for _, offer in StarwhaleConfig.offers do
			order += 10
			addOfferRow(offer, order, stardust)
			if offer.needsEgg and choosing then
				addEggRows(order + 1)
			end
		end
		list.CanvasPosition = scroll
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*" or path == "stardust" or string.sub(path, 1, 4) == "eggs"
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

return TillyTrade
