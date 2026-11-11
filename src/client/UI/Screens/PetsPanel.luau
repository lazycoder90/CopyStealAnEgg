--!nonstrict
-- Isi modal "Pets": header slot aktif, tombol +1 EQUIP, daftar semua pet (urut income, aktif dulu),
-- dan tombol Equip Best. Baris diperbarui langsung dari StateController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Progression = require(Shared.Config.Progression)
local Rarities = require(Shared.Config.Rarities)
local MutationLogic = require(Shared.Logic.MutationLogic)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local PetMath = require(Shared.Logic.PetMath)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local PetsPanel = {}

local ROW_HEIGHT = 56

local function sortedPets(state)
	local list = {}
	for uid, pet in state.get("pets") or {} do
		local ok, income = pcall(PetMath.petIncome, pet.id, pet.kg, pet.muts or {})
		table.insert(list, { uid = uid, pet = pet, income = ok and income or 0 })
	end
	table.sort(list, function(a, b)
		if a.pet.eq ~= b.pet.eq then
			return a.pet.eq == true
		end
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	return list
end

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

local function buildRow(item, parent: Instance, order: number)
	local pet = item.pet
	local creature = Creatures.get(pet.id)
	local rarity = Rarities.get(creature.rarity)
	local rc = Color3.fromRGB(rarity.rgb[1], rarity.rgb[2], rarity.rgb[3])
	local muts = MutationLogic.format(pet.muts or {})

	local row = UIBuilder.create("Frame", {
		Name = "Row_" .. item.uid,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		BackgroundColor3 = if pet.eq
			then Color3.fromRGB(255, 233, 180)
			else Color3.fromRGB(246, 232, 204),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		},
	})
	label({
		Name = "Name",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.4, 0, 0, 24),
		Font = Theme.Fonts.Title,
		TextColor3 = rc,
		Text = creature.name,
		Parent = row,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
		},
	})
	label({
		Name = "Detail",
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(0.4, 0, 0, 20),
		Text = string.format("%s  |  %.1f kg", NumberFormat.fmtRate(item.income), pet.kg)
			.. (if muts ~= "" then "  |  " .. muts else ""),
		Parent = row,
	})
	Button.new({
		name = "Lock",
		text = if pet.lock then "Locked" else "Lock",
		color = if pet.lock then Theme.Colors.Brick else Color3.fromRGB(150, 130, 110),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -112, 0.5, 0),
		size = UDim2.fromOffset(84, 36),
		textSize = 16,
		onClick = function()
			Net.send("LockPet", item.uid, not pet.lock)
		end,
		parent = row,
	}).ZIndex =
		5
	Button.new({
		name = "Equip",
		text = if pet.eq then "Unequip" else "Equip",
		color = if pet.eq then Theme.Colors.Brick else Theme.Colors.Mint,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		size = UDim2.fromOffset(96, 36),
		textSize = 16,
		onClick = function()
			Net.send(if pet.eq then "UnequipPet" else "EquipPet", item.uid)
		end,
		parent = row,
	}).ZIndex =
		5
end

-- container: frame konten dari ModalController; state: StateController. Mengembalikan fungsi pembersih.
function PetsPanel.build(container: Frame, state)
	local header = label({
		Name = "Header",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0.5, 0, 0, 34),
		Font = Theme.Fonts.Title,
		Text = "",
		Parent = container,
	})
	local buyButton = Button.new({
		name = "BuySlot",
		text = "+1 EQUIP",
		color = Theme.Colors.Mint,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -4, 0, 0),
		size = UDim2.fromOffset(190, 36),
		textSize = 18,
		onClick = function()
			Net.send("BuyEquipSlot")
		end,
		parent = container,
	})
	buyButton.ZIndex = 4

	local list = UIBuilder.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -100),
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
				Padding = UDim.new(0, 6),
			}),
		},
	})
	local empty = label({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "No pets yet. Hatch an egg!",
		Parent = container,
	})
	local best = Button.new({
		name = "EquipBest",
		text = "Equip Best",
		color = Theme.Colors.Yolk,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.fromScale(0.5, 1),
		size = UDim2.fromOffset(220, 46),
		onClick = function()
			Net.send("EquipBest")
		end,
		parent = container,
	})
	best.ZIndex = 4

	local function refresh()
		local slots = state.get("equipSlots") or Progression.startEquipSlots
		local equipped = 0
		local items = sortedPets(state)
		for _, item in items do
			if item.pet.eq then
				equipped += 1
			end
		end
		header.Text = `{equipped}/{slots} Active`
		local nextPrice = Progression.equipSlotPrices[slots + 1]
		if nextPrice and slots < Progression.maxEquipSlots then
			buyButton.Text = `+1 EQUIP [{NumberFormat.fmtMoney(nextPrice)}]`
			buyButton.Visible = true
		else
			buyButton.Visible = false
		end

		local scroll = list.CanvasPosition
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, item in items do
			buildRow(item, list, i)
		end
		list.CanvasPosition = scroll
		empty.Visible = #items == 0
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*"
			or path == "equipSlots"
			or path == "pets"
			or string.sub(path, 1, 5) == "pets."
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

return PetsPanel
