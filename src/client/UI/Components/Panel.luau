--!nonstrict
-- Panel krem dengan sudut membulat dan garis tepi cokelat.

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local Panel = {}

-- props: properti Frame tambahan (Size, Position, Parent, ...).
function Panel.new(props: { [any]: any }?)
	local frame = UIBuilder.create("Frame", {
		Name = "Panel",
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			frame[key] = value
		end
	end
	if props and props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

return Panel
