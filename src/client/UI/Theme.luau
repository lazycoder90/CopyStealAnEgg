-- Tema UI "Eggshell & Yolk" (docs/PLAN.md §1.2).

local Brick = Color3.fromRGB(198, 70, 52)

return {
	Colors = {
		Cream = Color3.fromRGB(255, 244, 222), -- panel
		Yolk = Color3.fromRGB(255, 190, 40), -- tombol utama
		YolkDark = Color3.fromRGB(214, 140, 10),
		Brown = Color3.fromRGB(86, 52, 28), -- stroke teks
		Brick = Brick, -- aksi bahaya (Drop, alert)
		Danger = Brick,
		Mint = Color3.fromRGB(110, 205, 120), -- sukses / cash
		White = Color3.fromRGB(255, 255, 255),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamMedium,
	},
	Corner = UDim.new(0, 12),
	StrokeThickness = 2,
	MinButtonHeight = 44,
}
