--!nonstrict
-- Isi modal "Trail Shop": kartu untuk tiap Trail (Buy / Equip / Unequip + label Equipped).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Progression = require(Shared.Config.Progression)
local Rarities = require(Shared.Config.Rarities)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local TrailsShop = {}

local CARD_SIZE = UDim2.fromOffset(200, 130)
local GRAY = Color3.fromRGB(150, 130, 110)

local function rarityColor(name: string): Color3
	for _, r in Rarities.list do
		if r.name == name then
			return Color3.fromRGB(r.rgb[1], r.rgb[2], r.rgb[3])
		end
	end
	return Theme.Colors.Brown
end

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

local function buildCard(trail, parent: Instance, order: number, state)
	local owned = state.get(`trails.owned.{trail.id}`) == true
	local equipped = state.get("trails.equipped") == trail.id
	local c = trail.color
	local card = UIBuilder.create("Frame", {
		Name = "Card_" .. trail.id,
		LayoutOrder = order,
		Size = CARD_SIZE,
		BackgroundColor3 = if equipped
			then Color3.fromRGB(255, 233, 180)
			else Color3.fromRGB(246, 232, 204),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UIBuilder.create("UIStroke", {
				Thickness = 2,
				Color = Color3.fromRGB(c[1], c[2], c[3]),
			}),
		},
	})
	text(card, {
		Name = "Name",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 24),
		Font = Theme.Fonts.Title,
		TextColor3 = rarityColor(trail.rarity),
		Text = trail.name,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
		},
	})
	text(card, {
		Name = "Mult",
		Position = UDim2.fromOffset(8, 34),
		Size = UDim2.new(1, -16, 0, 20),
		Text = `x{trail.mult} Speed`,
	})
	if equipped then
		text(card, {
			Name = "State",
			Position = UDim2.fromOffset(8, 56),
			Size = UDim2.new(1, -16, 0, 18),
			TextColor3 = Color3.fromRGB(60, 140, 70),
			Text = "Equipped",
		})
	elseif not owned then
		text(card, {
			Name = "Price",
			Position = UDim2.fromOffset(8, 56),
			Size = UDim2.new(1, -90, 0, 18),
			Text = NumberFormat.fmtMoney(trail.cashPrice),
		})
	end

	local label, color, onClick
	if owned and equipped then
		label, color = "Unequip", Theme.Colors.Brick
		onClick = function()
			Net.send("EquipTrail", trail.id)
		end
	elseif owned then
		label, color = "Equip", Theme.Colors.Yolk
		onClick = function()
			Net.send("EquipTrail", trail.id)
		end
	else
		label, color = "Buy " .. NumberFormat.fmtMoney(trail.cashPrice), Theme.Colors.Mint
		onClick = function()
			Net.send("BuyTrail", trail.id, "cash")
		end
	end
	local button = Button.new({
		name = "Action",
		text = label,
		color = color,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -6),
		size = UDim2.new(1, -16, 0, 34),
		textSize = 16,
		onClick = onClick,
		parent = card,
	})
	button.ZIndex = 5
	if not owned and trail.robuxPrice > 0 then
		-- Beli Robux belum tersedia: tampilkan abu-abu, tidak bisa diklik.
		local robux = Button.new({
			name = "Robux",
			text = `R$ {trail.robuxPrice}`,
			color = GRAY,
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, 54),
			size = UDim2.fromOffset(64, 22),
			textSize = 12,
			parent = card,
		})
		Button.setDisabled(robux, true)
		robux.ZIndex = 5
	end
end

-- container: frame konten dari ModalController; state: StateController. Mengembalikan pembersih.
function TrailsShop.build(container: Frame, state)
	local list = UIBuilder.create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
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
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, trail in Progression.trails do
			buildCard(trail, list, i, state)
		end
		list.CanvasPosition = scroll
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*" or string.sub(path, 1, 6) == "trails"
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

return TrailsShop
