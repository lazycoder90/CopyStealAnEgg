--!nonstrict
-- Toast bertumpuk (maks 3), pudar setelah ~3 detik.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local NotificationController = {}

local MAX_VISIBLE = 3
local LIFETIME = 3
local FADE = 0.4

local gui, list
local active = {} -- toast tertua di indeks 1
local pending = {} -- antrean sebelum gui siap
local order = 0

local KIND_COLORS = {
	error = { Theme.Colors.Brick, Theme.Colors.White },
	success = { Theme.Colors.Mint, Theme.Colors.Brown },
	info = { Theme.Colors.Cream, Theme.Colors.Brown },
	admin = { Theme.Colors.Yolk, Theme.Colors.Brown },
}

local function removeToast(toast)
	local idx = table.find(active, toast)
	if idx then
		table.remove(active, idx)
	end
	if toast.Parent then
		local info = TweenInfo.new(FADE)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		local label = toast:FindFirstChild("Label")
		if label then
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		end
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
		task.delay(FADE, function()
			toast:Destroy()
		end)
	end
end

local function show(message: string, kind: string)
	local colors = KIND_COLORS[kind] or KIND_COLORS.info
	order += 1
	local toast = UIBuilder.create("Frame", {
		Name = "Toast",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = colors[1],
		BorderSizePixel = 0,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
			UIBuilder.create("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Body,
				TextSize = 18,
				TextWrapped = true,
				TextColor3 = colors[2],
				Text = tostring(message),
			}),
		},
	})
	toast.Parent = list
	table.insert(active, toast)
	while #active > MAX_VISIBLE do
		removeToast(active[1])
	end
	task.delay(LIFETIME, function()
		if table.find(active, toast) then
			removeToast(toast)
		end
	end)
end

function NotificationController.push(message: string, kind: string?)
	if not list then
		table.insert(pending, { message, kind or "info" })
		return
	end
	show(message, kind or "info")
end

function NotificationController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Toasts",
		ResetOnSpawn = false,
		DisplayOrder = 80,
	})
	list = UIBuilder.create("Frame", {
		Name = "List",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 160),
		BackgroundTransparency = 1,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		},
	})
	UIBuilder.create("UISizeConstraint", { MaxSize = Vector2.new(420, 160), Parent = list })

	Net.connect("Notify", function(message, kind)
		NotificationController.push(message, kind)
	end)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		for _, item in pending do
			show(item[1], item[2])
		end
		pending = {}
	end)
end

return NotificationController
