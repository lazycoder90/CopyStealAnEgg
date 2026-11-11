--!nonstrict
-- RacePodium: kartu layar penuh saat race Closed. Judul "Dash Derby - Podium", baris 1ST/2ND/3RD
-- (nama, waktu mm:ss.cc, trophy), "+N Trophies" untuk pemain lokal. Tutup otomatis 15 detik atau saat diklik.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RaceConfig = require(Shared.Config.RaceConfig)
local RaceMath = require(Shared.Logic.RaceMath)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local RacePodium = {}

local PLACES = { "1ST", "2ND", "3RD" }
local PLACE_COLORS = {
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(200, 205, 215),
	Color3.fromRGB(214, 140, 80),
}

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Fonts.Title
	return UIBuilder.create("TextLabel", props)
end

local function row(parent: Instance, index: number, data, isMe: boolean)
	local frame = UIBuilder.create("Frame", {
		Name = "Row" .. index,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = if isMe then Theme.Colors.Yolk else Theme.Colors.White,
		BackgroundTransparency = if isMe then 0.2 else 0.4,
		BorderSizePixel = 0,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		},
	})
	text({
		Name = "Place",
		Size = UDim2.new(0, 56, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextSize = 24,
		TextColor3 = PLACE_COLORS[index],
		Text = PLACES[index],
		Parent = frame,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	text({
		Name = "Name",
		Size = UDim2.new(0, 150, 1, 0),
		Position = UDim2.fromOffset(68, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 20,
		TextColor3 = Theme.Colors.Brown,
		Text = if data then data.name else "---",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	text({
		Name = "Time",
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.fromOffset(222, 0),
		TextSize = 20,
		TextColor3 = Theme.Colors.Brown,
		Text = if data then RaceMath.formatTime(data.timeSeconds) else "--:--.--",
		Parent = frame,
	})
	text({
		Name = "Trophies",
		Size = UDim2.new(0, 90, 1, 0),
		Position = UDim2.new(1, -96, 0, 0),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Colors.Brown,
		Text = if data then RaceMath.commas(data.trophies) else "",
		Parent = frame,
	})
end

-- Menampilkan kartu. payload = RaceStatePayload (phase Closed). Mengembalikan fungsi close().
function RacePodium.show(parent: Instance, payload, onClosed: (() -> ())?)
	local podium = payload.podium or {}
	local myTrophies = payload.myTrophies or 0
	local localId = Players.LocalPlayer.UserId
	local closed = false

	local backdrop = UIBuilder.create("TextButton", {
		Name = "RacePodium",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	})
	local card = UIBuilder.create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 340),
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		Parent = backdrop,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }),
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
		},
	})
	text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 8),
		TextSize = 32,
		TextColor3 = Theme.Colors.Yolk,
		Text = "Dash Derby - Podium",
		Parent = card,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 3, Color = Theme.Colors.Brown }),
		},
	})
	text({
		Name = "Zone",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 52),
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = payload.zoneName or "",
		Parent = card,
	})
	local rows = UIBuilder.create("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 0, 150),
		BackgroundTransparency = 1,
		Parent = card,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		},
	})
	for index = 1, #PLACES do
		local data = podium[index]
		row(rows, index, data, data ~= nil and data.userId == localId)
	end
	if myTrophies > 0 then
		text({
			Name = "Reward",
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 244),
			TextSize = 30,
			TextColor3 = Theme.Colors.Mint,
			Text = `+{RaceMath.commas(myTrophies)} Trophies`,
			Parent = card,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 3, Color = Theme.Colors.Brown }),
			},
		})
	end
	if payload.myTrophyTotal then
		text({
			Name = "Total",
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 282),
			TextSize = 18,
			TextColor3 = Theme.Colors.Brown,
			Text = `Trophies: {RaceMath.commas(payload.myTrophyTotal)}`,
			Parent = card,
		})
	end
	text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -24),
		TextSize = 14,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Brown,
		TextTransparency = 0.3,
		Text = "Click to close",
		Parent = card,
	})

	local function close()
		if closed then
			return
		end
		closed = true
		backdrop:Destroy()
		if onClosed then
			onClosed()
		end
	end
	backdrop.MouseButton1Click:Connect(close)
	task.delay(RaceConfig.podiumSeconds, close)
	return close
end

return RacePodium
