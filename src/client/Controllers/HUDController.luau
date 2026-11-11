--!nonstrict
-- HUD minimal Fase 0: Speed dan Cash di kiri bawah + notifikasi admin.
-- HUD penuh (tombol Shop/Index/Eggs/Pets, hotbar, timer) dibangun di fase berikutnya.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local StateController = require(script.Parent.StateController)

local HUDController = {}

local function stat(name: string, order: number, color: Color3)
	return UIBuilder.create("TextLabel", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Title,
		TextSize = 28,
		TextColor3 = color,
		Text = "",
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
end

function HUDController.Start()
	local gui = UIBuilder.create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	local stack = UIBuilder.create("Frame", {
		Name = "BottomLeft",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(260, 80),
		BackgroundTransparency = 1,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
		},
	})

	local speed = stat("Speed", 1, Theme.Colors.White)
	local cash = stat("Cash", 2, Theme.Colors.Mint)
	speed.Parent = stack
	cash.Parent = stack

	local toast = UIBuilder.create("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 32),
		BackgroundColor3 = Theme.Colors.Cream,
		BackgroundTransparency = 0.1,
		Font = Theme.Fonts.Body,
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = "",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
		},
	})

	local function refresh()
		local s = StateController.get("speedBase") or 0
		local c = StateController.get("cash") or 0
		speed.Text = "Speed " .. NumberFormat.fmt(s)
		cash.Text = NumberFormat.fmtMoney(c)
	end

	StateController.changed:Connect(function(path)
		if path == "*" or path == "cash" or path == "speedBase" then
			refresh()
		end
	end)
	refresh()

	local toastId = 0
	Net.connect("Notify", function(message)
		toastId += 1
		local mine = toastId
		toast.Text = tostring(message)
		toast.Visible = true
		task.delay(3, function()
			if mine == toastId then
				toast.Visible = false
			end
		end)
	end)
end

return HUDController
