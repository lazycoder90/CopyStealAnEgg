--!nonstrict
-- Efek benturan di klien: knockback (impuls), ragdoll singkat, getar kamera, dan label "CAUGHT!".
-- Remote: Caught { knock, zone }, Bonked { knock }. Server menegakkan WalkSpeed=0 dan kebal pickup.
-- Karakter tidak boleh tertinggal macet: semua pemulihan lewat task.delay dan CharacterAdded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local ImpactController = {}

local MAX_KNOCK = 120
local RAGDOLL_SECONDS = 1.2
local CAUGHT_SHAKE = 1.2
local BONK_SHAKE = 0.7

local gui, caughtLabel
local ragdollId = 0
local flashId = 0
local shakeAmp, shakeEnd, shakeStart = 0, 0, 0
local shaking = false

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Getar kamera sederhana lewat Humanoid.CameraOffset; amplitudo meluruh sampai selesai.
function ImpactController.shake(amplitude: number, duration: number)
	local now = os.clock()
	if now < shakeEnd and amplitude < shakeAmp then
		return
	end
	shakeAmp = amplitude
	shakeStart = now
	shakeEnd = now + duration
end

local function updateShake()
	local now = os.clock()
	local humanoid = getHumanoid()
	if now >= shakeEnd then
		if shaking then
			shaking = false
			if humanoid then
				humanoid.CameraOffset = Vector3.zero
			end
		end
		return
	end
	if not humanoid then
		return
	end
	shaking = true
	local falloff = 1 - (now - shakeStart) / math.max(shakeEnd - shakeStart, 1e-3)
	local a = shakeAmp * falloff
	humanoid.CameraOffset =
		Vector3.new((math.random() - 0.5) * 2 * a, (math.random() - 0.5) * 2 * a, 0)
end

local function restoreCharacter()
	local humanoid = getHumanoid()
	if humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function applyKnock(knock: Vector3)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = getHumanoid()
	if not (root and humanoid) or humanoid.Health <= 0 then
		return
	end
	if knock.Magnitude > MAX_KNOCK then
		knock = knock.Unit * MAX_KNOCK
	end
	ragdollId += 1
	local mine = ragdollId
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = knock
	task.delay(RAGDOLL_SECONDS, function()
		if mine == ragdollId then
			restoreCharacter()
		end
	end)
end

local function flashCaught()
	flashId += 1
	local mine = flashId
	caughtLabel.Visible = true
	caughtLabel.TextTransparency = 0
	task.delay(0.6, function()
		if mine ~= flashId then
			return
		end
		TweenService:Create(caughtLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			if mine == flashId then
				caughtLabel.Visible = false
			end
		end)
	end)
end

local function validKnock(payload): Vector3?
	if type(payload) ~= "table" or typeof(payload.knock) ~= "Vector3" then
		return nil
	end
	return payload.knock
end

function ImpactController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Impact",
		ResetOnSpawn = false,
		DisplayOrder = 21,
		IgnoreGuiInset = true,
	})
	caughtLabel = UIBuilder.create("TextLabel", {
		Name = "Caught",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(400, 90),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 72,
		TextColor3 = Theme.Colors.Brick,
		Text = "CAUGHT!",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
		},
	})

	Net.connect("Caught", function(payload)
		local knock = validKnock(payload)
		if knock then
			applyKnock(knock)
		end
		flashCaught()
		ImpactController.shake(CAUGHT_SHAKE, 0.5)
	end)
	Net.connect("Bonked", function(payload)
		local knock = validKnock(payload)
		if knock then
			applyKnock(knock)
		end
		ImpactController.shake(BONK_SHAKE, 0.3)
	end)

	RunService.RenderStepped:Connect(updateShake)

	-- Karakter baru: jangan membawa sisa ragdoll atau getaran.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		ragdollId += 1
		shakeEnd = 0
		shaking = false
	end)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return ImpactController
