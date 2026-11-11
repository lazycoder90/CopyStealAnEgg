--!nonstrict
-- Skala UI: UIScale "NBScale" di tiap ScreenGui game (bukan gui inti Roblox) dari ukuran viewport
-- (AtmosphereMath.uiScaleForViewport). Dihitung ulang saat ViewportSize berubah dan saat ScreenGui baru muncul.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AtmosphereMath = require(Shared.Logic.AtmosphereMath)

local UIScaleController = {}

local SCALE_NAME = "NBScale"
-- Gui inti/milik Roblox yang tidak boleh diskalakan.
local EXCLUDED = {
	Chat = true,
	BubbleChat = true,
	Freecam = true,
	ProximityPrompts = true,
	TouchGui = true,
	ControlGui = true,
	PlayerList = true,
	Backpack = true,
	EmotesMenu = true,
	RobloxGui = true,
	PurchasePromptApp = true,
}

local currentScale = 1
local SMALL_SCREEN_HEIGHT = 600 -- hanya layar sentuh lebih pendek dari ini yang diskalakan
local guis = {} -- ScreenGui -> UIScale
local viewportConn

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function ensureScale(gui: ScreenGui)
	local scale = gui:FindFirstChild(SCALE_NAME)
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Parent = gui
	end
	scale.Scale = currentScale
	guis[gui] = scale
end

local function track(child: Instance)
	if not child:IsA("ScreenGui") or EXCLUDED[child.Name] then
		return
	end
	ensureScale(child)
	child.Destroying:Once(function()
		guis[child] = nil
	end)
end

-- Ukuran layar: Camera.ViewportSize bisa terbaca 1x1 sesaat (atau terus di beberapa lingkungan),
-- jadi jika tidak masuk akal pakai AbsoluteSize salah satu ScreenGui kita (tidak terpengaruh UIScale).
local function screenSize(): Vector2?
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X >= 100 and camera.ViewportSize.Y >= 100 then
		return camera.ViewportSize
	end
	for gui in guis do
		if gui.Parent and gui.AbsoluteSize.X >= 100 and gui.AbsoluteSize.Y >= 100 then
			return gui.AbsoluteSize
		end
	end
	return nil
end

local function recompute()
	local size = screenSize()
	if not size then
		return
	end
	-- PENTING: UIScale pada ScreenGui menyusutkan isinya ke pojok KIRI ATAS (posisi/anchor berbasis skala
	-- tidak ikut melebar), sehingga di desktop skala harus 1. Skala hanya dipakai pada perangkat sentuh
	-- berlayar pendek (ponsel landscape), dengan batas bawah dari AtmosphereMath. Lihat docs/KNOWN_ISSUES.md.
	local target = 1
	if touchOnly() and size.Y < SMALL_SCREEN_HEIGHT then
		target = AtmosphereMath.uiScaleForViewport(size.X, size.Y, true)
	end
	currentScale = target
	for _, scale in guis do
		scale.Scale = currentScale
	end
end

local function bindCamera()
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
	end
	recompute()
end

function UIScaleController.getScale(): number
	return currentScale
end

function UIScaleController.Start()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(recompute)

	task.spawn(function()
		-- Hitung ulang berkala (murah) untuk menangkap perubahan ukuran layar yang tidak memicu sinyal kamera.
		while true do
			task.wait(2)
			recompute()
		end
	end)

	task.spawn(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		playerGui.ChildAdded:Connect(track)
		for _, child in playerGui:GetChildren() do
			track(child)
		end
	end)
end

return UIScaleController
