--!nonstrict
-- Banner atas "You earned $X while away! ($Y/day offline)" ~6 detik dengan pudar.
-- Antrean aman (satu banner pada satu waktu); klik untuk menutup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Logic.NumberFormat)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local OfflineBannerController = {}

local SHOW_SECONDS = 6
local FADE_SECONDS = 0.5

local gui, banner, label, stroke
local queue = {}
local showing = false
local dismissed = false

local function fadeTo(transparency: number)
	local info = TweenInfo.new(FADE_SECONDS)
	TweenService:Create(banner, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(label, info, { TextTransparency = transparency }):Play()
	TweenService:Create(stroke, info, { Transparency = transparency }):Play()
end

local function showNext()
	if showing or #queue == 0 or not banner then
		return
	end
	showing = true
	dismissed = false
	local item = table.remove(queue, 1)
	label.Text =
		`You earned {NumberFormat.fmtMoney(item.amount)} while away! ({NumberFormat.fmtMoney(
			item.perDay
		)}/day offline)`
	banner.Visible = true
	fadeTo(0)
	task.spawn(function()
		local waited = 0
		while waited < SHOW_SECONDS and not dismissed do
			task.wait(0.1)
			waited += 0.1
		end
		fadeTo(1)
		task.wait(FADE_SECONDS)
		banner.Visible = false
		showing = false
		showNext()
	end)
end

function OfflineBannerController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "OfflineBanner",
		ResetOnSpawn = false,
		DisplayOrder = 70,
	})
	banner = UIBuilder.create("TextButton", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(520, 56),
		BackgroundColor3 = Theme.Colors.Yolk,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UISizeConstraint", { MaxSize = Vector2.new(520, 56) }),
		},
	})
	stroke = UIBuilder.create("UIStroke", {
		Thickness = Theme.StrokeThickness,
		Color = Theme.Colors.Brown,
		Transparency = 1,
		Parent = banner,
	})
	label = UIBuilder.create("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 22,
		TextWrapped = true,
		TextColor3 = Theme.Colors.White,
		TextTransparency = 1,
		Text = "",
		Parent = banner,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
	banner.Activated:Connect(function()
		dismissed = true
	end)

	Net.connect("OfflineEarnings", function(amount, perDay)
		if type(amount) ~= "number" or type(perDay) ~= "number" then
			return
		end
		table.insert(queue, { amount = amount, perDay = perDay })
		showNext()
	end)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return OfflineBannerController
