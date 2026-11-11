--!nonstrict
-- Isi modal Inventaris: tab Pets / Eggs / Gear, header "All Items", pencarian nama, dan label kapasitas.
-- Pets: Equip/Unequip/Lock (remote yang sama dengan panel Pets). Eggs: Place (kantong) / Pocket (ditaruh).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local MutationLogic = require(Shared.Logic.MutationLogic)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local PetMath = require(Shared.Logic.PetMath)
local Rarities = require(Shared.Config.Rarities)
local SellConfig = require(Shared.Config.SellConfig)
local SellMath = require(Shared.Logic.SellMath)
local Types = require(Shared.Types)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local InventoryPanel = {}

local ROW_HEIGHT = 56
local GREY = Color3.fromRGB(150, 130, 110)

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

local function rarityColor(creature): Color3
	local rgb = Rarities.get(creature.rarity).rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Titik penempatan: depan pemain (LookVector * jarak), dijepit ke lantai Coop sendiri bila ada.
local function placeTarget(): Vector3?
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local ahead = root.Position + root.CFrame.LookVector * SellConfig.placeLookDistance
	for _, coop in CollectionService:GetTagged(Types.Tags.Coop) do
		if coop:GetAttribute(Types.Attr.OwnerUserId) == player.UserId then
			local floor = coop:FindFirstChild(Types.Names.PlotFloor)
			if floor and floor:IsA("BasePart") then
				local cf = floor.CFrame
				local half = floor.Size * 0.5
				local tl = cf:PointToObjectSpace(ahead)
				local lx = math.clamp(tl.X, -(half.X - Eggs.placeInset), half.X - Eggs.placeInset)
				local lz = math.clamp(tl.Z, -(half.Z - Eggs.placeInset), half.Z - Eggs.placeInset)
				return cf:PointToWorldSpace(Vector3.new(lx, half.Y, lz))
			end
		end
	end
	return Vector3.new(ahead.X, 0, ahead.Z)
end

local function pill(props)
	return UIBuilder.create("TextButton", {
		Name = props.name,
		AutoButtonColor = false,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = props.color or GREY,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Title,
		TextSize = 18,
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

local function newRow(parent: Instance, name: string, order: number, color: Color3)
	return UIBuilder.create("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		},
	})
end

local ROW_COLOR = Color3.fromRGB(246, 232, 204)
local ROW_ACTIVE = Color3.fromRGB(255, 233, 180)

local function rowTexts(row: Frame, title: string, titleColor: Color3, detail: string)
	label({
		Name = "Name",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.5, 0, 0, 24),
		Font = Theme.Fonts.Title,
		TextColor3 = titleColor,
		Text = title,
		Parent = row,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
		},
	})
	label({
		Name = "Detail",
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(0.55, 0, 0, 20),
		Text = detail,
		Parent = row,
	})
end

local function rowButton(
	row: Frame,
	name: string,
	text: string,
	color: Color3,
	x: number,
	w: number,
	onClick
)
	local button = Button.new({
		name = name,
		text = text,
		color = color,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, x, 0.5, 0),
		size = UDim2.fromOffset(w, 36),
		textSize = 16,
		onClick = onClick,
		parent = row,
	})
	button.ZIndex = 5
	return button
end

-- container: frame konten modal; state: StateController; close: menutup modal.
function InventoryPanel.build(container: Frame, state, close: () -> ())
	local tab = "pets"
	local query = ""

	label({
		Name = "Header",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.fromOffset(120, 30),
		Font = Theme.Fonts.Title,
		Text = "All Items",
		Parent = container,
	})
	local capacity = label({
		Name = "Capacity",
		Position = UDim2.fromOffset(130, 2),
		Size = UDim2.new(1, -320, 0, 26),
		Text = "",
		Parent = container,
	})
	local search = UIBuilder.create("TextBox", {
		Name = "Search",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(180, 30),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Body,
		TextSize = 16,
		TextColor3 = Theme.Colors.Brown,
		PlaceholderText = "Search...",
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
		},
	})

	local tabButtons = {}
	local refresh
	for i, def in { { "pets", "Pets" }, { "eggs", "Eggs" }, { "gear", "Gear" } } do
		tabButtons[def[1]] = pill({
			name = "Tab" .. def[2],
			text = def[2],
			position = UDim2.fromOffset((i - 1) * 108, 36),
			size = UDim2.fromOffset(100, 34),
			parent = container,
		})
		tabButtons[def[1]].Activated:Connect(function()
			tab = def[1]
			refresh()
		end)
	end

	local list = UIBuilder.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 1, -78),
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
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = container,
	})

	local function buildPets(): number
		local items = {}
		for uid, pet in state.get("pets") or {} do
			local ok, creature = pcall(Creatures.get, pet.id)
			if ok and SellMath.matches(creature.name, query) then
				table.insert(items, {
					uid = uid,
					pet = pet,
					creature = creature,
					income = PetMath.petIncome(pet.id, pet.kg, pet.muts or {}),
				})
			end
		end
		table.sort(items, function(a, b)
			if a.pet.eq ~= b.pet.eq then
				return a.pet.eq == true
			end
			if a.income ~= b.income then
				return a.income > b.income
			end
			return a.uid < b.uid
		end)
		for i, item in items do
			local pet = item.pet
			local row =
				newRow(list, "Row_" .. item.uid, i, if pet.eq then ROW_ACTIVE else ROW_COLOR)
			local muts = MutationLogic.format(pet.muts or {})
			rowTexts(
				row,
				item.creature.name,
				rarityColor(item.creature),
				string.format("%s  |  %.1f kg", NumberFormat.fmtRate(item.income), pet.kg)
					.. (if muts ~= "" then "  |  " .. muts else "")
			)
			rowButton(
				row,
				"Lock",
				if pet.lock then "Locked" else "Lock",
				if pet.lock then Theme.Colors.Brick else GREY,
				-112,
				84,
				function()
					Net.send("LockPet", item.uid, not pet.lock)
				end
			)
			rowButton(
				row,
				"Equip",
				if pet.eq then "Unequip" else "Equip",
				if pet.eq then Theme.Colors.Brick else Theme.Colors.Mint,
				-8,
				96,
				function()
					Net.send(if pet.eq then "UnequipPet" else "EquipPet", item.uid)
				end
			)
		end
		return #items
	end

	local function buildEggs(): number
		local items = {}
		for uid, egg in state.get("eggs") or {} do
			local ok, creature = pcall(Creatures.get, egg.id)
			if ok and SellMath.matches(creature.name, query) then
				table.insert(items, { uid = uid, egg = egg, creature = creature })
			end
		end
		table.sort(items, function(a, b)
			if a.egg.loc ~= b.egg.loc then
				return a.egg.loc == "pocket"
			end
			return a.uid < b.uid
		end)
		for i, item in items do
			local egg = item.egg
			local pocket = egg.loc == "pocket"
			local row =
				newRow(list, "Row_" .. item.uid, i, if pocket then ROW_ACTIVE else ROW_COLOR)
			local income = PetMath.eggProjectedIncome(egg.id, egg.kg, egg.muts or {})
			rowTexts(
				row,
				item.creature.name .. " Egg",
				rarityColor(item.creature),
				string.format(
					"%s  |  %.1f kg  |  %s",
					NumberFormat.fmtRate(income),
					egg.kg,
					if pocket then "In pocket" else "In Coop"
				)
			)
			if pocket then
				rowButton(row, "Place", "Place", Theme.Colors.Mint, -8, 96, function()
					local target = placeTarget()
					if target then
						Net.send("PlaceFromInventory", item.uid, target)
						close()
					end
				end)
			else
				rowButton(row, "Pocket", "Pocket", Theme.Colors.Yolk, -8, 96, function()
					Net.send("PocketEgg", item.uid)
				end)
			end
		end
		return #items
	end

	local function buildGear(): number
		local order = 0
		local function infoRow(title: string, detail: string, active: boolean)
			if not SellMath.matches(title, query) then
				return
			end
			order += 1
			local row =
				newRow(list, "Gear_" .. order, order, if active then ROW_ACTIVE else ROW_COLOR)
			rowTexts(row, title, Theme.Colors.Brown, detail)
		end
		for _, info in SellConfig.gearInfo do
			infoRow(info.name, info.detail, false)
		end
		local boosts = state.get("boosts") or {}
		for _, key in SellConfig.boostOrder do
			local value = boosts[key]
			if type(value) == "number" and value > 0 then
				infoRow(SellConfig.boostNames[key] or key, "Active", true)
			end
		end
		return order
	end

	refresh = function()
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == tab then Theme.Colors.Yolk else GREY
		end
		local scroll = list.CanvasPosition
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local count
		if tab == "pets" then
			count = buildPets()
			empty.Text = "No pets found."
		elseif tab == "eggs" then
			count = buildEggs()
			empty.Text = "No eggs found."
		else
			count = buildGear()
			empty.Text = "Nothing here."
		end
		list.CanvasPosition = scroll
		empty.Visible = count == 0

		local petCount, pocketCount = 0, 0
		for _ in state.get("pets") or {} do
			petCount += 1
		end
		for _, egg in state.get("eggs") or {} do
			if egg.loc == "pocket" then
				pocketCount += 1
			end
		end
		capacity.Text =
			`Pets: {petCount}/{Eggs.petCapacity}   Eggs: pocket {pocketCount}/{Eggs.pocketCapacity}`
	end
	refresh()

	local dirty = false
	local alive = true
	local function schedule()
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
	local connection = state.changed:Connect(function(path)
		local head = string.sub(path, 1, 5)
		local relevant = path == "*"
			or path == "pets"
			or path == "eggs"
			or path == "boosts"
			or head == "pets."
			or head == "eggs."
			or head == "boost"
		if relevant and string.sub(path, -9) ~= ".progress" then
			schedule()
		end
	end)
	local searchConnection = search:GetPropertyChangedSignal("Text"):Connect(function()
		query = search.Text
		schedule()
	end)

	return function()
		alive = false
		connection:Disconnect()
		searchConnection:Disconnect()
	end
end

return InventoryPanel
