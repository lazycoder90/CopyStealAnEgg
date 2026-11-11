--!nonstrict
-- Isi modal "Yolk Lab": 3 pilihan mutasi (nama, pengali, peluang sukses, aturan harga).
-- Memilih salah satu memanggil onSelect(mutName); pengendali menutup modal dan masuk mode APPLY.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Mutations = require(Shared.Config.Mutations)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local MutationPanel = {}

MutationPanel.colors = {
	Pearl = Color3.fromRGB(225, 225, 245),
	Amber = Color3.fromRGB(255, 176, 60),
	Starlit = Color3.fromRGB(150, 130, 255),
}

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

local function fmtMult(m: number): string
	return "x" .. (string.gsub(string.format("%.2f", m), "%.?0+$", ""))
end

-- container: frame konten dari ModalController. Mengembalikan fungsi pembersih.
function MutationPanel.build(container: Frame, onSelect: (string) -> ())
	label({
		Name = "Intro",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 0, 40),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Professor Albumen can mutate an egg growing in your Coop. If it fails, the money is lost!",
		Parent = container,
	})
	local row = UIBuilder.create("Frame", {
		Name = "Options",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
		},
	})
	for _, name in CollectionConfig.mutation.options do
		local def = Mutations.list[name]
		local card = UIBuilder.create("Frame", {
			Name = "Option_" .. name,
			Size = UDim2.new(0.3, 0, 0, 280),
			BackgroundColor3 = Color3.fromRGB(246, 232, 204),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = row,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 12) }),
				UIBuilder.create("UIStroke", { Thickness = 3, Color = MutationPanel.colors[name] }),
			},
		})
		label({
			Name = "Name",
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.new(1, -16, 0, 36),
			Font = Theme.Fonts.Title,
			TextColor3 = MutationPanel.colors[name],
			Text = name,
			Parent = card,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
			},
		})
		label({
			Name = "Mult",
			Position = UDim2.fromOffset(8, 54),
			Size = UDim2.new(1, -16, 0, 30),
			Font = Theme.Fonts.Title,
			Text = fmtMult(def.mult) .. " income",
			Parent = card,
		})
		label({
			Name = "Chance",
			Position = UDim2.fromOffset(8, 94),
			Size = UDim2.new(1, -16, 0, 26),
			Text = `Success: {math.floor(def.npcSuccess * 100 + 0.5)}%`,
			Parent = card,
		})
		label({
			Name = "Price",
			Position = UDim2.fromOffset(8, 128),
			Size = UDim2.new(1, -16, 0, 44),
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
			Text = `Price: {def.npcPriceMult} x the egg's $/s`,
			Parent = card,
		})
		local button = Button.new({
			name = "Select",
			text = "SELECT",
			color = Theme.Colors.Mint,
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -12),
			size = UDim2.new(1, -24, 0, 46),
			textSize = 22,
			onClick = function()
				onSelect(name)
			end,
			parent = card,
		})
		button.ZIndex = 5
	end
	return function() end
end

return MutationPanel
