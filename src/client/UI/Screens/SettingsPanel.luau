--!nonstrict
-- Panel Settings (isi modal): baris toggle ON (mint) / OFF (abu) + tombol Replay intro.
-- api = { get(key) -> boolean, toggle(key), replay() }, changed = Signal(path) dari StateController.
-- Tombol dibuat ulang tiap perubahan karena Button menimpa warna saat hover.

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local SettingsPanel = {}

local OFF_COLOR = Color3.fromRGB(150, 140, 130)

local ROWS = {
	{ key = "music", label = "Music", comingSoon = true },
	{ key = "sfx", label = "Sound Effects" },
	{ key = "lowGfx", label = "Low Graphics" },
	{ key = "slowMode", label = "Slow Mode" },
}

-- Mengembalikan fungsi pembersih.
function SettingsPanel.build(container: Frame, api, changed)
	local list = UIBuilder.create("ScrollingFrame", {
		Name = "SettingsList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = container,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			UIBuilder.create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
		},
	})

	local toggles = {} -- key -> Button

	local function renderToggle(row, parent: Instance)
		local old = toggles[row.key]
		if old then
			old:Destroy()
		end
		local on = api.get(row.key)
		local text = if row.comingSoon then "Coming soon" elseif on then "ON" else "OFF"
		local button = Button.new({
			name = "Toggle_" .. row.key,
			text = text,
			color = if row.comingSoon or not on then OFF_COLOR else Theme.Colors.Mint,
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -4, 0.5, 0),
			size = UDim2.fromOffset(row.comingSoon and 140 or 96, Theme.MinButtonHeight),
			textSize = 20,
			onClick = function()
				api.toggle(row.key)
			end,
			parent = parent,
		})
		if row.comingSoon then
			Button.setDisabled(button, true)
		end
		toggles[row.key] = button
	end

	local rowFrames = {}
	for i, row in ROWS do
		local frame = UIBuilder.create("Frame", {
			Name = "Row_" .. row.key,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Theme.Colors.White,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = list,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
				UIBuilder.create("TextLabel", {
					Name = "Label",
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -170, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = Theme.Fonts.Title,
					TextSize = 22,
					TextColor3 = Theme.Colors.Brown,
					Text = row.label,
				}),
			},
		})
		rowFrames[row.key] = frame
		renderToggle(row, frame)
	end

	UIBuilder.create("Frame", {
		Name = "ReplayRow",
		LayoutOrder = #ROWS + 1,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = list,
		[UIBuilder.Children] = {
			Button.new({
				name = "Replay",
				text = "Replay intro",
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.fromScale(0, 0.5),
				size = UDim2.fromOffset(190, Theme.MinButtonHeight),
				textSize = 20,
				onClick = api.replay,
			}),
		},
	})

	local conn = changed:Connect(function(path)
		if path == "*" or path == "settings" or string.sub(path, 1, 9) == "settings." then
			for _, row in ROWS do
				renderToggle(row, rowFrames[row.key])
			end
		end
	end)

	return function()
		conn.Disconnect()
		list:Destroy()
	end
end

return SettingsPanel
