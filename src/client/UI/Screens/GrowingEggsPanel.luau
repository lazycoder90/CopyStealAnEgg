--!nonstrict
-- Isi modal "Growing Eggs": semua telur placed dan pocket. Sisa waktu dihitung dari progress yang
-- direplikasi server dan digambar ulang tiap detik. Telur siap punya tombol Open (HatchEgg).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Rarities = require(Shared.Config.Rarities)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local GrowingEggsPanel = {}

local ROW_HEIGHT = 56

local function isReady(egg): boolean
	return egg.progress >= egg.growTotal
end

-- Jumlah telur placed yang sedang tumbuh dan yang siap.
function GrowingEggsPanel.counts(state): (number, number)
	local growing, ready = 0, 0
	local eggs = state.get("eggs")
	if type(eggs) == "table" then
		for _, egg in eggs do
			if egg.loc == "placed" then
				if isReady(egg) then
					ready += 1
				else
					growing += 1
				end
			end
		end
	end
	return growing, ready
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

-- Urutan: siap dulu, lalu sisa waktu terkecil; telur kantong di akhir.
local function sortedEggs(state)
	local list = {}
	for uid, egg in state.get("eggs") or {} do
		local ok, creature = pcall(Creatures.get, egg.id)
		if ok then
			table.insert(list, { uid = uid, egg = egg, creature = creature })
		end
	end
	local function rank(item)
		if item.egg.loc == "pocket" then
			return 3
		end
		return if isReady(item.egg) then 1 else 2
	end
	table.sort(list, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		local ta, tb = a.egg.growTotal - a.egg.progress, b.egg.growTotal - b.egg.progress
		if ta ~= tb then
			return ta < tb
		end
		return a.uid < b.uid
	end)
	return list
end

local function statusText(egg): string
	if egg.loc == "pocket" then
		return "In bag"
	end
	if isReady(egg) then
		return "Egg Ready!"
	end
	return NumberFormat.fmtTime(egg.growTotal - egg.progress)
end

-- container: frame konten modal; state: StateController. Mengembalikan fungsi pembersih.
function GrowingEggsPanel.build(container: Frame, state)
	local header = label({
		Name = "Header",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0.5, 0, 0, 34),
		Font = Theme.Fonts.Title,
		Text = "",
		Parent = container,
	})
	local growAll = Button.new({
		name = "GrowAll",
		text = "Grow All (R$)",
		color = Theme.Colors.Yolk,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -4, 0, 0),
		size = UDim2.fromOffset(230, 36),
		textSize = 16,
		onClick = function()
			Net.send("RequestGrowAll") -- server membalas "belum tersedia" selama ID produk masih 0
		end,
		parent = container,
	})
	growAll.ZIndex = 4

	local list = UIBuilder.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
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
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "No eggs yet. Grab one and place it in your Coop!",
		Parent = container,
	})

	local rows = {} -- uid -> { status = TextLabel, ready = bool, loc = string }

	local function buildRow(item, order: number)
		local egg = item.egg
		local rarity = Rarities.get(item.creature.rarity)
		local rc = Color3.fromRGB(rarity.rgb[1], rarity.rgb[2], rarity.rgb[3])
		local ready = isReady(egg)

		local row = UIBuilder.create("Frame", {
			Name = "Row_" .. item.uid,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = if ready and egg.loc == "placed"
				then Color3.fromRGB(214, 242, 214)
				else Color3.fromRGB(246, 232, 204),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = list,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			},
		})
		label({
			Name = "Name",
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.45, 0, 0, 24),
			Font = Theme.Fonts.Title,
			TextColor3 = rc,
			Text = item.creature.name .. " Egg",
			Parent = row,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 1, Color = Theme.Colors.Brown }),
			},
		})
		local status = label({
			Name = "Status",
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(0.45, 0, 0, 20),
			Text = "",
			Parent = row,
		})
		label({
			Name = "Kg",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -240, 0.5, 0),
			Size = UDim2.fromOffset(70, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = string.format("%.1f kg", egg.kg),
			Parent = row,
		})
		if egg.loc == "placed" then
			if ready then
				Button.new({
					name = "Open",
					text = "Open",
					color = Theme.Colors.Mint,
					anchorPoint = Vector2.new(1, 0.5),
					position = UDim2.new(1, -8, 0.5, 0),
					size = UDim2.fromOffset(96, 36),
					textSize = 16,
					onClick = function()
						Net.send("HatchEgg", item.uid)
					end,
					parent = row,
				}).ZIndex =
					5
			else
				local skip = Button.new({
					name = "Skip",
					text = "Skip (R$)",
					color = Theme.Colors.Yolk,
					anchorPoint = Vector2.new(1, 0.5),
					position = UDim2.new(1, -8, 0.5, 0),
					size = UDim2.fromOffset(150, 36),
					textSize = 14,
					onClick = function()
						Net.send("RequestSkipGrowth", item.uid)
					end,
					parent = row,
				})
				skip.ZIndex = 5
			end
		end
		rows[item.uid] = { status = status, ready = ready, loc = egg.loc }
	end

	local function refresh()
		local items = sortedEggs(state)
		local scroll = list.CanvasPosition
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		rows = {}
		for i, item in items do
			buildRow(item, i)
		end
		list.CanvasPosition = scroll
		empty.Visible = #items == 0
		local growing, ready = GrowingEggsPanel.counts(state)
		header.Text = `Growing: {growing}   Ready: {ready}`
	end

	-- Perbarui hanya teks hitung mundur; bangun ulang jika struktur (siap/loc/daftar) berubah.
	local function tickLabels(): boolean
		local eggs = state.get("eggs") or {}
		local count = 0
		for uid, egg in eggs do
			local row = rows[uid]
			if not row or row.ready ~= isReady(egg) or row.loc ~= egg.loc then
				return false
			end
			count += 1
		end
		for uid, row in rows do
			local egg = eggs[uid]
			if egg then
				row.status.Text = statusText(egg)
			end
		end
		local rowCount = 0
		for _ in rows do
			rowCount += 1
		end
		return rowCount == count
	end

	local dirty = false
	local alive = true
	local function schedule()
		if not dirty then
			dirty = true
			task.defer(function()
				dirty = false
				if alive then
					refresh()
					tickLabels()
				end
			end)
		end
	end
	local connection = state.changed:Connect(function(path)
		if path == "*" or path == "eggs" then
			schedule()
		elseif string.sub(path, 1, 5) == "eggs." then
			-- progress berubah tiap detik: ditangani loop hitung mundur, bukan bangun ulang.
			if string.sub(path, -9) ~= ".progress" then
				schedule()
			end
		end
	end)

	refresh()
	tickLabels()
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				local growing, ready = GrowingEggsPanel.counts(state)
				header.Text = `Growing: {growing}   Ready: {ready}`
				if not tickLabels() then
					refresh()
					tickLabels()
				end
			end
		end
	end)

	return function()
		alive = false
		connection:Disconnect()
	end
end

return GrowingEggsPanel
