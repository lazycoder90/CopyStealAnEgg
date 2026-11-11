--!nonstrict
-- RaceHud: panel kecil kiri-atas saat race Open: nama zona, "Checkpoint n/7", timer pribadi, rekor, sisa waktu.
-- Timer dihitung lokal dari os.clock sejak sinkron terakhir dengan server (server mengirim tiap 1 detik).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RaceMath = require(Shared.Logic.RaceMath)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local RaceHud = {}
RaceHud.__index = RaceHud

local GATES_TOTAL = RaceMath.finishIndex

local function label(name: string, order: number, size: number, color: Color3, parent: Instance)
	return UIBuilder.create("TextLabel", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 4),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Title,
		TextSize = size,
		TextColor3 = color,
		Text = "",
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
end

function RaceHud.new(parent: Instance)
	local self = setmetatable({}, RaceHud)
	self.state = nil
	self.receivedAt = 0
	self.frame = UIBuilder.create("Frame", {
		Name = "RaceHud",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(230, 128),
		BackgroundColor3 = Theme.Colors.Brown,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			UIBuilder.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		},
	})
	self.zone = label("Zone", 1, 18, Theme.Colors.Yolk, self.frame)
	self.checkpoint = label("Checkpoint", 2, 16, Theme.Colors.White, self.frame)
	self.timer = label("Timer", 3, 28, Theme.Colors.White, self.frame)
	self.best = label("Best", 4, 16, Theme.Colors.Mint, self.frame)
	self.closes = label("Closes", 5, 14, Theme.Colors.Cream, self.frame)
	return self
end

function RaceHud:setState(state, receivedAt: number)
	self.state = state
	self.receivedAt = receivedAt
	self.frame.Visible = state ~= nil and state.phase == "Open"
	self:render()
end

function RaceHud:render()
	local state = self.state
	if not state or state.phase ~= "Open" then
		return
	end
	local sinceSync = os.clock() - self.receivedAt
	self.zone.Text = `Dash Derby: {state.zoneName or "?"}`
	local attempt = state.myAttempt
	if attempt then
		self.checkpoint.Text = `Checkpoint {attempt.checkpoint}/{GATES_TOTAL}`
		self.timer.Text = RaceMath.formatTime(attempt.elapsedSeconds + sinceSync)
	else
		self.checkpoint.Text = "Cross the START gate!"
		self.timer.Text = "--:--.--"
	end
	self.best.Text = if state.myBest then `Best {RaceMath.formatTime(state.myBest)}` else "Best --"
	local left = math.max(0, math.ceil(state.remaining - sinceSync))
	self.closes.Text = string.format("Closes in %d:%02d", left // 60, left % 60)
end

function RaceHud:destroy()
	self.frame:Destroy()
end

return RaceHud
