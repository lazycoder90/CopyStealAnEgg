--!nonstrict
-- Tombol pil (default kuning telur) dengan tween hover/tekan dan status disabled.

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local Button = {}

local TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- props: text, color, textColor, size, position, anchorPoint, textSize, layoutOrder, parent, onClick.
-- Mengembalikan TextButton; pakai Button.setDisabled(button, bool) untuk menonaktifkan.
function Button.new(props: { [string]: any })
	local color = props.color or Theme.Colors.Yolk
	local size = props.size or UDim2.fromOffset(140, Theme.MinButtonHeight)
	local scale = UIBuilder.create("UIScale", { Scale = 1 })

	local button = UIBuilder.create("TextButton", {
		Name = props.name or "Button",
		AutoButtonColor = false,
		AnchorPoint = props.anchorPoint or Vector2.zero,
		Position = props.position or UDim2.new(),
		Size = size,
		LayoutOrder = props.layoutOrder or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Title,
		TextSize = props.textSize or 22,
		TextColor3 = props.textColor or Theme.Colors.White,
		Text = props.text or "",
		[UIBuilder.Children] = {
			scale,
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", {
				Name = "TextStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
	-- Garis tepi tombol (border) terpisah dari stroke teks.
	local border = UIBuilder.create("UIStroke", {
		Name = "Border",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = Theme.StrokeThickness,
		Color = Theme.Colors.Brown,
		Parent = button,
	})
	button:SetAttribute("BaseColor", color)

	local disabled = false
	local function tweenTo(inst, goal)
		TweenService:Create(inst, TWEEN, goal):Play()
	end

	button.MouseEnter:Connect(function()
		if not disabled then
			tweenTo(button, { BackgroundColor3 = color:Lerp(Theme.Colors.White, 0.2) })
		end
	end)
	button.MouseLeave:Connect(function()
		tweenTo(button, { BackgroundColor3 = disabled and Theme.Colors.Brown or color })
		tweenTo(scale, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if not disabled then
			tweenTo(scale, { Scale = 0.94 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(scale, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if not disabled and props.onClick then
			props.onClick()
		end
	end)

	button:GetAttributeChangedSignal("Disabled"):Connect(function()
		disabled = button:GetAttribute("Disabled") == true
		button.BackgroundColor3 = disabled and Color3.fromRGB(150, 130, 110) or color
		button.TextTransparency = disabled and 0.35 or 0
		border.Transparency = disabled and 0.4 or 0
	end)

	if props.parent then
		button.Parent = props.parent
	end
	return button
end

function Button.setDisabled(button: TextButton, value: boolean)
	button:SetAttribute("Disabled", value)
end

return Button
