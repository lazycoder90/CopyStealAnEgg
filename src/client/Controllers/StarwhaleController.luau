--!nonstrict
-- Sisi klien event Starwhale: (1) panah kompas saat Star Compass dipegang (kedip makin cepat saat dekat,
-- jarak dalam stud; tanpa audio), (2) banner status kunjungan, (3) telur aneh dirender LOKAL (hanya
-- klien ini) lalu dikirim CollectOddEgg(index) saat pemain mendekat 6 stud, (4) chip "Stardust: N".
-- State datang dari S2C StarwhaleState; waktu = sisa detik (dihitung mundur lokal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)
local Zones = require(Shared.Config.Zones)
local StarwhaleMath = require(Shared.Logic.StarwhaleMath)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local StateController = require(script.Parent.StateController)

local Attr = Types.Attr
local LocalPlayer = Players.LocalPlayer

local StarwhaleController = {}

local CFG = StarwhaleConfig
local CYAN = Color3.fromRGB(110, 230, 255)
local FLASH = Color3.fromRGB(255, 255, 255)
local PURPLE = Color3.fromRGB(190, 150, 255)

local gui, compassFrame, arrow, arrowParts, distanceLabel, hintLabel, banner, chip
local state = nil -- payload terakhir
local receivedAt = 0
local equipped = false
local nextBeep = 0
local flashUntil = 0
local eggFolder = nil
local eggs = {} -- [index] = { part, base: Vector3, sent: boolean }
local hooked = {}

local function root(): BasePart?
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function fmtLeft(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== telur aneh (lokal) =====

local function clearEggs()
	for _, egg in eggs do
		egg.part:Destroy()
	end
	eggs = {}
end

local function syncEggs()
	local positions = state and state.phase == "Found" and state.oddPositions
	if not positions then
		clearEggs()
		return
	end
	if not eggFolder then
		eggFolder = Instance.new("Folder")
		eggFolder.Parent = workspace
	end
	for index = 1, CFG.oddCount do
		local pos = positions[index]
		local existing = eggs[index]
		if pos and #pos == 3 then
			if not existing then
				local part = Instance.new("Part")
				part.Shape = Enum.PartType.Ball
				part.Size = Vector3.new(2.6, 3.2, 2.6)
				part.Color = Color3.fromRGB(255, 120 + index * 30, 255 - index * 40)
				part.Material = Enum.Material.Neon
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part:SetAttribute(Attr.OddEgg, index)
				local light = Instance.new("PointLight")
				light.Color = part.Color
				light.Range = 14
				light.Brightness = 2
				light.Parent = part
				part.Position = Vector3.new(pos[1], pos[2], pos[3])
				part.Parent = eggFolder
				existing = { part = part, base = part.Position, sent = false }
				eggs[index] = existing
			end
			existing.sent = false -- server menghitung ulang: boleh dikirim lagi bila belum diterima
			existing.part.Parent = eggFolder
		elseif existing then
			existing.part:Destroy()
			eggs[index] = nil
		end
	end
end

local function updateEggs(now: number)
	local hrp = root()
	for index, egg in eggs do
		local bobY = math.sin(now * 2 + index) * 0.5
		egg.part.Position = egg.base + Vector3.new(0, bobY, 0)
		egg.part.CFrame = CFrame.new(egg.part.Position) * CFrame.Angles(0, now * 1.5, 0)
		if
			hrp
			and not egg.sent
			and (hrp.Position - egg.base).Magnitude <= CFG.collectClientRadius
		then
			egg.sent = true
			egg.part.Parent = nil -- sembunyikan sementara; muncul lagi bila server menolak
			Net.send("CollectOddEgg", index)
		end
	end
end

-- ===== kompas =====

local function hookTool(tool: Instance)
	if not (tool:IsA("Tool") and tool.Name == CFG.compassToolName) or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Equipped:Connect(function()
		equipped = true
	end)
	tool.Unequipped:Connect(function()
		equipped = false
	end)
	if tool.Parent == LocalPlayer.Character then
		equipped = true
	end
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

local function onCharacter(character: Model)
	equipped = false
	watch(character)
	task.spawn(function()
		local backpack = LocalPlayer:WaitForChild("Backpack", 10)
		if backpack and not hooked[backpack] then
			hooked[backpack] = true
			watch(backpack)
		end
	end)
end

local function setArrowColor(color: Color3)
	for _, part in arrowParts do
		part.BackgroundColor3 = color
	end
end

local function remainingNow(): number
	if not state then
		return 0
	end
	return math.max(0, state.remaining - (os.clock() - receivedAt))
end

local function updateCompass(now: number)
	local target = state and state.target
	local hrp = root()
	local show = equipped and target ~= nil and hrp ~= nil
	compassFrame.Visible = show
	if not show then
		return
	end
	local camera = workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
	local pos = hrp.Position
	arrow.Rotation = StarwhaleMath.bearing(pos.X, pos.Z, target[1], target[3], look.X, look.Z)
	local distance = math.sqrt((target[1] - pos.X) ^ 2 + (target[3] - pos.Z) ^ 2)
	distanceLabel.Text = `{math.floor(distance + 0.5)} studs`
	if now >= nextBeep then
		nextBeep = now + StarwhaleMath.blinkInterval(distance)
		flashUntil = now + 0.09
	end
	setArrowColor(if now < flashUntil then FLASH else CYAN)
end

-- ===== banner dan chip =====

local function updateBanner()
	local text
	if state and state.phase == "Found" then
		text =
			`STARWHALE FOUND! Find {state.oddEggsTotal or 3} odd eggs! {state.oddEggs or 0}/{state.oddEggsTotal or 3}`
	elseif state and state.phase == "Done" then
		text = "Crack the crystal pods for Stardust!"
	elseif state and state.phase == "Sighted" then
		local zone = Zones.list[state.zone or 0]
		text = `Starwhale sighted in {zone and zone.name or "the lane"}! Leaves in {fmtLeft(
			remainingNow()
		)}`
	end
	banner.Visible = text ~= nil
	if text then
		banner.Text = text
	end
	local hasCompass = StateController.get("gear.compass") == 1
	hintLabel.Visible = hasCompass and not equipped and state ~= nil and state.phase == "Sighted"

	local stardust = StateController.get("stardust") or 0
	local active = state ~= nil and state.phase ~= "Idle"
	chip.Visible = stardust > 0 or active
	chip.Text = `Stardust: {stardust}`
end

local function buildUi()
	gui = UIBuilder.create("ScreenGui", {
		Name = "StarwhaleHUD",
		ResetOnSpawn = false,
		DisplayOrder = 4,
	})
	banner = UIBuilder.create("TextLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(460, 30),
		BackgroundColor3 = Color3.fromRGB(40, 36, 90),
		BackgroundTransparency = 0.25,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = PURPLE,
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	UIBuilder.create("UISizeConstraint", { MaxSize = Vector2.new(460, 30), Parent = banner })

	compassFrame = UIBuilder.create("Frame", {
		Name = "Compass",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(140, 124),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	arrow = UIBuilder.create("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		Parent = compassFrame,
	})
	local head = UIBuilder.create("Frame", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(42, 20),
		Size = UDim2.fromOffset(26, 26),
		Rotation = 45,
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Parent = arrow,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	local shaft = UIBuilder.create("Frame", {
		Name = "Shaft",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(42, 30),
		Size = UDim2.fromOffset(10, 40),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Parent = arrow,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	arrowParts = { head, shaft }
	distanceLabel = UIBuilder.create("TextLabel", {
		Name = "Distance",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(130, 26),
		BackgroundColor3 = Color3.fromRGB(40, 36, 90),
		BackgroundTransparency = 0.25,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Colors.White,
		Text = "",
		Parent = compassFrame,
		[UIBuilder.Children] = { UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) },
	})
	hintLabel = UIBuilder.create("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(300, 24),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 16,
		TextColor3 = CYAN,
		TextStrokeTransparency = 0.3,
		Text = "Hold your Compass to track it!",
		Visible = false,
		Parent = gui,
	})
	chip = UIBuilder.create("TextLabel", {
		Name = "StardustChip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -198),
		Size = UDim2.fromOffset(170, 34),
		BackgroundColor3 = Color3.fromRGB(70, 56, 140),
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Colors.White,
		Text = "Stardust: 0",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
end

function StarwhaleController.Start()
	buildUi()

	Net.connect("StarwhaleState", function(payload)
		if type(payload) ~= "table" then
			return
		end
		state = payload
		receivedAt = os.clock()
		syncEggs()
		updateBanner()
	end)

	LocalPlayer.CharacterAdded:Connect(onCharacter)
	if LocalPlayer.Character then
		onCharacter(LocalPlayer.Character)
	end

	StateController.changed:Connect(function(path)
		if path == "*" or path == "stardust" or path == "gear.compass" then
			updateBanner()
		end
	end)

	local bannerAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		updateCompass(now)
		updateEggs(now)
		bannerAcc += dt
		if bannerAcc >= 0.25 then
			bannerAcc = 0
			updateBanner()
		end
	end)

	task.spawn(function()
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return StarwhaleController
