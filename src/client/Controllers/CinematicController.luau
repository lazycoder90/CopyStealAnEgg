--!nonstrict
-- Intro sinematik 5 detik untuk pemain baru: kamera tinggi di atas hub -> pintu lane -> kembali ke
-- karakter, judul "Nest Bandits" dan tombol Skip (tombol/klik apa pun setelah 1 detik juga skip).
-- Kamera SELALU dipulihkan (CameraType = Custom + subject) lewat pembersihan akhir, meski error/skip/respawn.
-- Klien tidak pernah menulis cinematicSeen; server mengisinya sendiri (CinematicService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local PolishConfig = require(Shared.Config.PolishConfig)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local StateController = require(script.Parent.StateController)

local CinematicController = {}

local cfg = PolishConfig.cinematic
local LocalPlayer = Players.LocalPlayer

local running = false
local evaluated = false

local function waitForRoot(timeout: number)
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and workspace.CurrentCamera then
			return root, humanoid
		end
		task.wait(0.2)
	end
	return nil, nil
end

local function buildGui()
	local function bar(name: string, anchorY: number)
		return UIBuilder.create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, anchorY),
			Position = UDim2.fromScale(0, anchorY),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		})
	end
	local title = UIBuilder.create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(720, 120),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 92,
		TextColor3 = Theme.Colors.Yolk,
		Text = "Nest Bandits",
		TextTransparency = 1,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", {
				Thickness = 5,
				Color = Theme.Colors.Brown,
				Transparency = 1,
			}),
		},
	})
	local gui = UIBuilder.create("ScreenGui", {
		Name = "Cinematic",
		ResetOnSpawn = false,
		DisplayOrder = 90,
		IgnoreGuiInset = true,
		[UIBuilder.Children] = { bar("Top", 0), bar("Bottom", 1), title },
	})
	return gui, title
end

-- Menunggu tween selesai atau skip; mengembalikan true bila di-skip.
local function runTween(session, instance: Instance, seconds: number, goal, style)
	if session.skipped then
		return true
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style, Enum.EasingDirection.InOut),
		goal
	)
	session.tween = tween
	local done = false
	local conn = tween.Completed:Connect(function()
		done = true
	end)
	tween:Play()
	-- Batas waktu keras: jika klien tidak merender (tween tidak maju), intro tetap berakhir dan kamera dipulihkan.
	local startedAt = os.clock()
	while not done and not session.skipped and os.clock() - startedAt < seconds + 1.5 do
		task.wait()
	end
	conn:Disconnect()
	tween:Cancel()
	session.tween = nil
	return session.skipped
end

local function body(session, root: BasePart, camera: Camera)
	local rootPos = root.Position
	local lane = Vector3.new(0, 10, Layout.laneStartZ + 80)
	local high = CFrame.lookAt(rootPos + Vector3.new(0, cfg.highHeight, -cfg.backDistance), rootPos)
	local laneView = CFrame.lookAt(Vector3.new(0, 55, Layout.laneStartZ - 90), lane)
	local behind = CFrame.lookAt(rootPos + Vector3.new(0, 8, -16), rootPos + Vector3.new(0, 3, 0))

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = high

	-- Judul muncul lalu memudar selama perjalanan kamera.
	local fadeIn = TweenService:Create(session.title, TweenInfo.new(0.8), { TextTransparency = 0 })
	local fadeStroke =
		TweenService:Create(session.title.UIStroke, TweenInfo.new(0.8), { Transparency = 0 })
	fadeIn:Play()
	fadeStroke:Play()

	local total = cfg.seconds
	if runTween(session, camera, total * 0.44, { CFrame = laneView }, Enum.EasingStyle.Sine) then
		return
	end
	TweenService:Create(session.title, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	TweenService:Create(session.title.UIStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	if
		runTween(
			session,
			camera,
			total * 0.2,
			{ CFrame = laneView * CFrame.new(0, 0, -10) },
			Enum.EasingStyle.Linear
		)
	then
		return
	end
	runTween(session, camera, total * 0.36, { CFrame = behind }, Enum.EasingStyle.Sine)
end

-- Memainkan intro. Tidak memeriksa state sehingga run(true) dari tombol Replay intro selalu jalan
-- (pemeriksaan pemain baru hanya ada di evaluate()). Argumen apa pun diabaikan.
function CinematicController.run()
	if running then
		return
	end
	running = true

	local session = { skipped = false, tween = nil, title = nil }
	task.delay(
		cfg.seconds + 8,
		function() -- pengaman terakhir: intro tidak boleh berlangsung tanpa batas
			session.skipped = true
		end
	)
	local connections = {}
	local gui

	local function finish()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		if session.tween then
			session.tween:Cancel()
		end
		-- Pemulihan kamera: tipe Custom dan subject ke Humanoid karakter saat ini.
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		if gui then
			gui:Destroy()
			gui = nil
		end
		running = false
	end

	local ok, err = xpcall(function()
		local root = waitForRoot(cfg.characterWait)
		if not root then
			return -- karakter tidak termuat: lewati diam-diam
		end
		local camera = workspace.CurrentCamera

		local title
		gui, title = buildGui()
		session.title = title
		local startedAt = os.clock()
		local skip = Button.new({
			name = "Skip",
			text = "Skip",
			color = Theme.Colors.Brick,
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -24, 0.88, -12),
			size = UDim2.fromOffset(110, Theme.MinButtonHeight),
			parent = gui,
			onClick = function()
				session.skipped = true
			end,
		})
		skip.ZIndex = 5
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input)
				if
					os.clock() - startedAt >= cfg.skipAfter
					and (
						input.UserInputType == Enum.UserInputType.Keyboard
						or input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					session.skipped = true
				end
			end)
		)
		-- Respawn saat intro berjalan: batalkan supaya kamera tidak tertinggal.
		table.insert(
			connections,
			LocalPlayer.CharacterAdded:Connect(function()
				session.skipped = true
			end)
		)

		body(session, root, camera)
	end, debug.traceback)

	finish()
	if not ok then
		warn("[CinematicController] intro gagal:", err)
	end
end

function CinematicController.isRunning(): boolean
	return running
end

local function evaluate()
	if evaluated then
		return
	end
	evaluated = true
	local step = StateController.get("tutorial.step")
	local done = StateController.get("tutorial.done")
	local seen = StateController.get("cinematicSeen")
	if step == 1 and done == false and seen == false then
		task.spawn(CinematicController.run)
	end
end

function CinematicController.Start()
	-- Evaluasi sekali saat snapshot pertama tiba.
	StateController.changed:Connect(function(path)
		if path == "*" then
			evaluate()
		end
	end)
	if StateController.isReady then
		task.spawn(evaluate)
	end
end

return CinematicController
