--!nonstrict
-- Isi modal "Fuse Machine": daftar spesies yang punya >= 3 pet layak (tidak aktif, tidak terkunci),
-- pilih spesies lalu 3 pet (otomatis 3 terlemah, bisa diganti), tampil Luck %, biaya, dan tombol FUSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Creatures = require(Shared.Config.Creatures)
local FuseLogic = require(Shared.Logic.FuseLogic)
local ModelFactory = require(Shared.ModelFactory)
local MutationLogic = require(Shared.Logic.MutationLogic)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local PetMath = require(Shared.Logic.PetMath)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local FusePanel = {}

local NEED = CollectionConfig.fuse.petCount
local ROW_H = 46

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

-- Pet layak per spesies: { [speciesId] = { {uid, pet, income}, ... } } urut income naik (terlemah dulu).
local function eligibleBySpecies(state)
	local out = {}
	for uid, pet in state.get("pets") or {} do
		if not pet.eq and not pet.lock and Creatures.byId[pet.id] then
			out[pet.id] = out[pet.id] or {}
			table.insert(out[pet.id], {
				uid = uid,
				pet = pet,
				income = PetMath.petIncome(pet.id, pet.kg, pet.muts or {}),
			})
		end
	end
	for _, list in out do
		table.sort(list, function(a, b)
			if a.income ~= b.income then
				return a.income < b.income
			end
			return a.uid < b.uid
		end)
	end
	return out
end

-- container: frame konten dari ModalController; state: StateController. Mengembalikan fungsi pembersih.
function FusePanel.build(container: Frame, state)
	local speciesId = nil
	local selected = {} -- urutan uid terpilih (maks NEED)

	label({
		Name = "Intro",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Bring 3 same creatures to Fuse! Better creatures give more Luck!",
		Parent = container,
	})

	local speciesList = UIBuilder.create("ScrollingFrame", {
		Name = "Species",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(0, 220, 1, -100),
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
				Padding = UDim.new(0, 4),
			}),
		},
	})
	local petList = UIBuilder.create("ScrollingFrame", {
		Name = "Pets",
		Position = UDim2.fromOffset(230, 32),
		Size = UDim2.new(1, -230, 1, -100),
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
				Padding = UDim.new(0, 4),
			}),
		},
	})
	local empty = label({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.fromOffset(220, 60),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 16,
		Text = "You need 3 unequipped, unlocked copies of the same creature.",
		Parent = container,
	})

	local luckLabel = label({
		Name = "Luck",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -34),
		Size = UDim2.new(0.5, 0, 0, 26),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = container,
	})
	local costLabel = label({
		Name = "Cost",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -2),
		Size = UDim2.new(0.5, 0, 0, 28),
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(60, 140, 70),
		Text = "",
		Parent = container,
	})
	local fuseButton = Button.new({
		name = "Fuse",
		text = "FUSE",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -4, 1, -2),
		size = UDim2.fromOffset(200, 54),
		textSize = 28,
		onClick = function()
			if #selected == NEED then
				Net.send("FuseSubmit", table.clone(selected))
			end
		end,
		parent = container,
	})
	fuseButton.ZIndex = 4

	local refresh

	local function rebuildSelection(list)
		-- Buang pilihan yang tidak lagi layak; isi ulang dengan pet terlemah bila kurang dari NEED.
		local valid = {}
		local byUid = {}
		for _, item in list do
			byUid[item.uid] = item
		end
		for _, uid in selected do
			if byUid[uid] then
				table.insert(valid, uid)
			end
		end
		selected = valid
		if #selected < NEED then
			selected = {}
			for i = 1, math.min(NEED, #list) do
				table.insert(selected, list[i].uid)
			end
		end
	end

	local function toggle(uid: string)
		local idx = table.find(selected, uid)
		if idx then
			table.remove(selected, idx)
		else
			if #selected >= NEED then
				table.remove(selected, 1)
			end
			table.insert(selected, uid)
		end
		refresh()
	end

	function refresh()
		local bySpecies = eligibleBySpecies(state)

		-- Daftar spesies dengan >= 3 pet layak, urut zona/slot.
		for _, child in speciesList:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local any = false
		if speciesId and not (bySpecies[speciesId] and #bySpecies[speciesId] >= NEED) then
			speciesId = nil
			selected = {}
		end
		for order, creature in Creatures.list do
			local list = bySpecies[creature.id]
			if list and #list >= NEED then
				any = true
				local rc = ModelFactory.rarityColor(creature.rarity)
				local row = UIBuilder.create("TextButton", {
					Name = "Species_" .. creature.id,
					LayoutOrder = order,
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.new(1, -8, 0, ROW_H),
					BackgroundColor3 = if creature.id == speciesId
						then Color3.fromRGB(255, 220, 130)
						else Color3.fromRGB(246, 232, 204),
					BorderSizePixel = 0,
					ZIndex = 4,
					Parent = speciesList,
					[UIBuilder.Children] = {
						UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
					},
				})
				label({
					Position = UDim2.fromOffset(8, 3),
					Size = UDim2.new(1, -16, 0, 22),
					Font = Theme.Fonts.Title,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = rc,
					Text = creature.name,
					Parent = row,
					[UIBuilder.Children] = {
						UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
					},
				})
				label({
					Position = UDim2.fromOffset(8, 26),
					Size = UDim2.new(1, -16, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = `{#list} available`,
					Parent = row,
				})
				row.Activated:Connect(function()
					speciesId = creature.id
					selected = {}
					refresh()
				end)
			end
		end
		empty.Visible = not any

		-- Daftar pet spesies terpilih.
		for _, child in petList:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local list = speciesId and bySpecies[speciesId] or {}
		if speciesId then
			rebuildSelection(list)
		end
		for order, item in list do
			local on = table.find(selected, item.uid) ~= nil
			local muts = MutationLogic.format(item.pet.muts or {})
			local row = UIBuilder.create("TextButton", {
				Name = "Pet_" .. item.uid,
				LayoutOrder = order,
				AutoButtonColor = false,
				Text = "",
				Size = UDim2.new(1, -8, 0, ROW_H),
				BackgroundColor3 = if on
					then Color3.fromRGB(190, 235, 190)
					else Color3.fromRGB(246, 232, 204),
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = petList,
				[UIBuilder.Children] = {
					UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				},
			})
			label({
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.new(1, -60, 0, 22),
				Font = Theme.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.format(
					"%s  |  %.1f kg",
					NumberFormat.fmtRate(item.income),
					item.pet.kg
				),
				Parent = row,
			})
			label({
				Position = UDim2.fromOffset(10, 26),
				Size = UDim2.new(1, -60, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = if muts ~= "" then muts else "No mutations",
				Parent = row,
			})
			label({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(36, 30),
				Font = Theme.Fonts.Title,
				TextColor3 = Color3.fromRGB(60, 140, 70),
				Text = if on then "OK" else "",
				Parent = row,
			})
			row.Activated:Connect(function()
				toggle(item.uid)
			end)
		end

		-- Luck, biaya, tombol.
		local picked = {}
		for _, uid in selected do
			for _, item in list do
				if item.uid == uid then
					table.insert(
						picked,
						{ id = item.pet.id, kg = item.pet.kg, muts = item.pet.muts or {} }
					)
				end
			end
		end
		if #picked == NEED then
			local cost = FuseLogic.cost(picked)
			luckLabel.Text = `Luck: {math.floor(FuseLogic.luck(picked) * 100 + 0.5)}%`
			costLabel.Text = `Cost: {NumberFormat.fmtMoney(cost)}`
			Button.setDisabled(fuseButton, (state.get("cash") or 0) < cost)
		else
			luckLabel.Text = if speciesId then `Pick {NEED} creatures` else ""
			costLabel.Text = ""
			Button.setDisabled(fuseButton, true)
		end
	end

	local dirty = false
	local alive = true
	local connection = state.changed:Connect(function(path)
		local relevant = path == "*"
			or path == "cash"
			or string.sub(path, 1, 5) == "pets."
			or path == "pets"
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

return FusePanel
