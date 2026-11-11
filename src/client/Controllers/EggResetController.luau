--!nonstrict
-- Chip "Reset in m:ss" di kanan bawah (di atas chip siang/malam). Server mengirim sisa detik;
-- klien menghitung mundur. 5 detik terakhir memakai BigCountdown bersama milik DayNightController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventsConfig = require(Shared.Config.EventsConfig)
local CycleMath = require(Shared.Logic.CycleMath)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local DayNightController = require(script.Parent.DayNightController)

local EggResetController = {}

local label
local endsAt = nil
local accumulator = 0

local function refresh()
	if not endsAt then
		return
	end
	local remaining = math.max(0, endsAt - os.clock())
	label.Text = "Reset in " .. CycleMath.formatClock(remaining)
	if remaining > 0 and remaining <= EventsConfig.eggReset.hudBigSeconds then
		DayNightController.setBig("reset", `Reset in {math.ceil(remaining - 1e-9)}`)
	else
		DayNightController.setBig("reset", nil)
	end
end

function EggResetController.Start()
	local chip = UIBuilder.create("Frame", {
		Name = "EggResetChip",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(170, 32),
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		Parent = DayNightController.getChipStack(),
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
	label = UIBuilder.create("TextLabel", {
		Name = "Time",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = "Reset in --:--",
		Parent = chip,
	})

	Net.connect("EggReset", function(payload)
		if type(payload) ~= "table" or type(payload.remaining) ~= "number" then
			return
		end
		endsAt = os.clock() + payload.remaining
		refresh()
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		refresh()
	end)
end

return EggResetController
