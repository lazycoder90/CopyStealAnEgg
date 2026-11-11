--!nonstrict
-- Layar reveal saat telur menetas: telur bergetar + retak, flash, lalu kartu makhluk.
-- Beberapa reveal diantre. Selalu bisa ditutup (tombol OK, klik, atau otomatis 6 detik).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local ModelFactory = require(Shared.ModelFactory)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local MutationLogic = require(Shared.Logic.MutationLogic)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local Panel = require(UI.Components.Panel)

local HatchRevealController = {}

local SHAKE_TIME = 1.2
local CLICK_DELAY = 1.5
local AUTO_CLOSE = 6

local queue = {}
local running = false

local function fmtKg(kg: number): string
	if kg >= 1000 then
		return NumberFormat.fmt(kg) .. " kg"
	end
	return string.format("%.1f kg", kg)
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Fonts.Title
	return UIBuilder.create("TextLabel", props)
end

local function stroked(props, thickness: number?)
	local label = text(props)
	UIBuilder.create("UIStroke", {
		Thickness = thickness or 2,
		Color = Theme.Colors.Brown,
		Parent = label,
	})
	return label
end

-- Menunggu sampai kondisi benar atau waktu habis; mengembalikan true jika kondisi terpenuhi.
local function waitUntil(cond: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if cond() then
			return true
		end
		task.wait(0.03)
	end
	return cond()
end

local function playEgg(session, data, root)
	local maid = session.maid
	local rarityColor = ModelFactory.rarityColor(data.rarity)

	local egg = UIBuilder.create("Frame", {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(150, 195),
		BackgroundColor3 = Theme.Colors.Cream:Lerp(rarityColor, 0.35),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = root,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
		},
	})
	local spots = { { 0.3, 0.3 }, { 0.65, 0.5 }, { 0.4, 0.7 } }
	for _, s in spots do
		UIBuilder.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(s[1], s[2]),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = rarityColor,
			BorderSizePixel = 0,
			Parent = egg,
			[UIBuilder.Children] = {
				UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			},
		})
	end
	local cracks = {}
	local crackDefs = {
		{ 0.5, 0.3, 40, 20 },
		{ 0.4, 0.45, 80, 70 },
		{ 0.6, 0.55, 30, 90 },
		{ 0.45, 0.68, 70, 60 },
		{ 0.55, 0.8, 50, 40 },
	}
	for _, c in crackDefs do
		local line = UIBuilder.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(c[3], 4),
			Rotation = c[4],
			BackgroundColor3 = Theme.Colors.Brown,
			BorderSizePixel = 0,
			Visible = false,
			Parent = egg,
		})
		table.insert(cracks, line)
	end

	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local p = math.clamp((os.clock() - t0) / SHAKE_TIME, 0, 1)
		egg.Rotation = math.sin((os.clock() - t0) * (30 + 40 * p)) * (3 + 14 * p)
		for i, line in cracks do
			line.Visible = p >= i / (#cracks + 1)
		end
	end)
	maid:Give(conn)
	waitUntil(function()
		return session.closed or session.skip
	end, SHAKE_TIME)
	conn:Disconnect()
	egg:Destroy()
end

local function showCard(session, data, root)
	local maid = session.maid
	local rarityColor = ModelFactory.rarityColor(data.rarity)
	local rarityName = Rarities.get(data.rarity).name

	-- Flash putih.
	local flash = UIBuilder.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = root,
	})
	local flashTween =
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	flashTween:Play()
	task.delay(0.55, function()
		flash:Destroy()
	end)

	local card = Panel.new({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 470),
		Parent = root,
	})
	-- Kartu mengecil pada layar pendek (ponsel landscape).
	local screenCamera = workspace.CurrentCamera
	local fit = screenCamera and math.clamp((screenCamera.ViewportSize.Y - 24) / 470, 0.5, 1) or 1
	local cardScale = UIBuilder.create("UIScale", { Scale = fit * 0.6, Parent = card })
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fit })
		:Play()
	local viewport = UIBuilder.create("ViewportFrame", {
		Name = "Viewport",
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 170),
		BackgroundColor3 = rarityColor:Lerp(Theme.Colors.Cream, 0.7),
		BorderSizePixel = 0,
		Parent = card,
		[UIBuilder.Children] = { UIBuilder.create("UICorner", { CornerRadius = Theme.Corner }) },
	})

	local ok, creature = pcall(Creatures.get, data.speciesId)
	if ok then
		local model = ModelFactory.makeCreature(creature, data.kg or 1, data.muts)
		model.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local size = model:GetExtentsSize()
		local radius = math.max(size.X, size.Y, size.Z)
		local distance = (radius * 0.5) / math.tan(math.rad(20)) * 1.5 + radius * 0.5
		camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.35, distance), Vector3.zero)
		local t0 = os.clock()
		maid:Give(RunService.RenderStepped:Connect(function()
			model:PivotTo(CFrame.Angles(0, (os.clock() - t0) * 0.9, 0))
		end))
	end

	local rarityLabel = stroked({
		Name = "Rarity",
		Position = UDim2.fromOffset(10, 194),
		Size = UDim2.new(1, -20, 0, 48),
		TextSize = 42,
		TextColor3 = rarityColor,
		Text = string.upper(rarityName),
		Parent = card,
	}, 3)
	if data.rarity >= 5 then
		rarityLabel.TextColor3 = Theme.Colors.White
		local gradient = UIBuilder.create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarityColor),
				ColorSequenceKeypoint.new(0.5, Theme.Colors.White),
				ColorSequenceKeypoint.new(1, rarityColor),
			}),
			Parent = rarityLabel,
		})
		gradient.Offset = Vector2.new(-1, 0)
		local shimmer = TweenService:Create(
			gradient,
			TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Offset = Vector2.new(1, 0) }
		)
		shimmer:Play()
		maid:Give(function()
			shimmer:Cancel()
		end)
	end

	local fullName = (#data.muts > 0 and (MutationLogic.format(data.muts) .. " ") or "")
		.. data.name
	text({
		Name = "Name",
		Position = UDim2.fromOffset(10, 246),
		Size = UDim2.new(1, -20, 0, 52),
		TextSize = 24,
		TextWrapped = true,
		TextColor3 = Theme.Colors.Brown,
		Text = fullName,
		Parent = card,
	})
	stroked({
		Name = "Income",
		Position = UDim2.fromOffset(10, 300),
		Size = UDim2.new(1, -20, 0, 34),
		TextSize = 28,
		TextColor3 = Theme.Colors.Mint,
		Text = NumberFormat.fmtRate(data.income or 0),
		Parent = card,
	})
	text({
		Name = "Details",
		Position = UDim2.fromOffset(10, 338),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Theme.Fonts.Body,
		TextSize = 20,
		TextColor3 = Theme.Colors.Brown,
		Text = fmtKg(data.kg or 0) .. "  -  " .. (data.gender == "F" and "Female" or "Male"),
		Parent = card,
	})
	if data.isNew then
		stroked({
			Name = "NewTag",
			Position = UDim2.fromOffset(250, 8),
			Size = UDim2.fromOffset(80, 36),
			Rotation = 12,
			TextSize = 26,
			TextColor3 = Theme.Colors.Yolk,
			Text = "NEW!",
			ZIndex = 5,
			Parent = card,
		}, 3)
	end

	Button.new({
		name = "OK",
		text = "OK",
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -16),
		size = UDim2.fromOffset(140, 48),
		onClick = function()
			session.closed = true
		end,
		parent = card,
	})
end

local function runReveal(data, gui)
	local session = { closed = false, skip = false, maid = Maid.new() }

	local backdrop = UIBuilder.create("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = gui,
	})
	session.maid:Give(backdrop)
	local cardShownAt
	backdrop.Activated:Connect(function()
		if not cardShownAt then
			session.skip = true
		elseif os.clock() - cardShownAt >= CLICK_DELAY then
			session.closed = true
		end
	end)

	local ok, err = pcall(function()
		playEgg(session, data, backdrop)
		if not session.closed then
			showCard(session, data, backdrop)
			cardShownAt = os.clock()
			waitUntil(function()
				return session.closed
			end, AUTO_CLOSE)
		end
	end)
	if not ok then
		warn("[HatchReveal] gagal:", err)
	end
	session.closed = true
	session.maid:Clean()
end

local function processQueue()
	if running then
		return
	end
	running = true
	local gui = UIBuilder.create("ScreenGui", {
		Name = "HatchReveal",
		ResetOnSpawn = false,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	while #queue > 0 do
		local data = table.remove(queue, 1)
		runReveal(data, gui)
		task.wait(0.15)
	end
	gui:Destroy()
	running = false
end

local function onReveal(data)
	if type(data) ~= "table" or type(data.rarity) ~= "number" then
		return
	end
	data.muts = type(data.muts) == "table" and data.muts or {}
	data.name = tostring(data.name or "Creature")
	table.insert(queue, data)
	task.spawn(processQueue)
end

function HatchRevealController.isActive(): boolean
	return running
end

function HatchRevealController.Start()
	Net.connect("HatchReveal", onReveal)
	Net.connect("FuseResult", onReveal) -- payload sama + upgraded/prism
end

return HatchRevealController
