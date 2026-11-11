--!nonstrict
-- Modal: panel dengan bilah judul + tombol X dan frame konten. Backdrop gelap menutupi layar.

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Panel = require(script.Parent.Panel)
local Button = require(script.Parent.Button)

local Modal = {}

-- Mengembalikan { backdrop = Frame, panel = Frame, content = Frame }.
-- onClose dipanggil saat X atau backdrop diklik.
function Modal.new(parent: Instance, title: string, onClose: () -> ())
	local backdrop = UIBuilder.create("TextButton", {
		Name = "ModalBackdrop",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 1,
		Parent = parent,
	})
	backdrop.Activated:Connect(onClose)

	local panel = Panel.new({
		Name = "ModalPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = 2,
		Parent = backdrop,
	})
	UIBuilder.create("UISizeConstraint", {
		MaxSize = Vector2.new(720, 520),
		MinSize = Vector2.new(260, 220),
		Parent = panel,
	})
	-- Klik di dalam panel tidak boleh menutup modal.
	UIBuilder.create("TextButton", {
		Name = "Shield",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ZIndex = 2,
		Parent = panel,
	})

	UIBuilder.create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -80, 0, 40),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Title,
		TextSize = 28,
		TextColor3 = Theme.Colors.Brown,
		Text = title,
		ZIndex = 3,
		Parent = panel,
	})
	local close = Button.new({
		name = "Close",
		text = "X",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 6),
		size = UDim2.fromOffset(44, 44),
		onClick = onClose,
		parent = panel,
	})
	close.ZIndex = 4

	local content = UIBuilder.create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 1, -68),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panel,
	})
	return { backdrop = backdrop, panel = panel, content = content }
end

return Modal
