--!nonstrict
-- NextUpdateService: papan hub "NEXT UPDATE" dengan hitung mundur ke MonetizationConfig.nextUpdateAt
-- (unix detik; 0 = belum diketahui -> "Coming soon!"). Memakai waktu NYATA (os.time), bukan Clock.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local MonetizationMath = require(Shared.Logic.MonetizationMath)
local Types = require(Shared.Types)

local NextUpdateService = {}

local BOARD_NAME = "NextUpdateBoard"
local BOARD_Y = 9

local countdownLabel

local function currentText(): string
	local at = MonetizationConfig.nextUpdateAt
	if at <= 0 then
		return "Coming soon!"
	end
	local remaining = at - os.time()
	if remaining <= 0 then
		return "Out now!"
	end
	return MonetizationMath.formatCountdown(remaining)
end

local function buildBoard()
	local parent = workspace:FindFirstChild(Types.Names.Map) or workspace
	local spot = Layout.hubStalls.nextUpdate
	local model = Instance.new("Model")
	model.Name = BOARD_NAME

	local wood = Color3.fromRGB(110, 76, 44)
	for _, dx in { -9, 9 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(1, BOARD_Y + 3, 1)
		post.Position = Vector3.new(spot.x + dx, (BOARD_Y + 3) / 2, spot.z + 0.8)
		post.Color = wood
		post.Material = Enum.Material.Wood
		post.Anchored = true
		post.Parent = model
	end

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Size = Vector3.new(22, 11, 1)
	board.Position = Vector3.new(spot.x, BOARD_Y, spot.z)
	board.Color = Color3.fromRGB(86, 52, 28)
	board.Material = Enum.Material.Wood
	board.Anchored = true
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth
	board.Parent = model

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front -- sisi -Z menghadap spawn pad
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(440, 220)
	gui.Parent = board

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 244, 222)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	title.BorderSizePixel = 0
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(86, 52, 28)
	title.Text = "NEXT UPDATE"
	title.Parent = bg

	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.Position = UDim2.fromOffset(0, 80)
	label.Size = UDim2.new(1, 0, 0, 110)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 54
	label.TextColor3 = Color3.fromRGB(86, 52, 28)
	label.Text = currentText()
	label.Parent = bg
	countdownLabel = label

	model.Parent = parent
end

function NextUpdateService.Init()
	buildBoard()
end

function NextUpdateService.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		if countdownLabel and countdownLabel.Parent then
			countdownLabel.Text = currentText()
		end
	end)
end

return NextUpdateService
