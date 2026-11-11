--!nonstrict
-- Bud (companion) di klien: tombol HUD kanan "Bud" (badge "!" saat bisa diklaim), modal "Grow Your Bud"
-- dan model Bud lokal yang mengikuti karakter pemain (tunas bercahaya, skala menurut stage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionMath = require(Shared.Logic.CompanionMath)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local CompanionPanel = require(UI.Screens.CompanionPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local CompanionController = {}

local MODAL = "Companion"
local FOLDER_NAME = Types.Names.ClientBud
local FOLLOW_OFFSET = CFrame.new(-3, 1.8, 2.5) -- kiri-belakang karakter
local FOLLOW_RATE = 8
local LEAF_COLOR = Color3.fromRGB(110, 205, 120)

local bud -- Model
local budBase = CFrame.new()
local currentScale = 1
local heartbeat
local bobClock = 0

local function folder(): Folder
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

local function part(model: Model, name: string, className: string, size: Vector3, color: Color3)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Tunas: bola kuning kecil + 2 daun baji + PointLight.
local function buildBud(): Model
	local model = Instance.new("Model")
	model.Name = "Bud"
	local ball = part(model, "Ball", "Part", Vector3.new(1.2, 1.2, 1.2), Theme.Colors.Yolk)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	for i, side in { -1, 1 } do
		local leaf = part(model, "Leaf" .. i, "WedgePart", Vector3.new(0.2, 0.8, 0.9), LEAF_COLOR)
		leaf.CFrame = CFrame.new(side * 0.55, 0.95, 0) * CFrame.Angles(0, 0, math.rad(side * 35))
	end
	ball.CFrame = CFrame.new(0, 0, 0)
	model.PrimaryPart = ball
	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.Yolk
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = ball
	return model
end

local function stageNow(): number
	local companion = StateController.get("companion")
	return CompanionMath.clampStage(companion and companion.stage)
end

local function destroyBud()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if bud then
		bud:Destroy()
		bud = nil
	end
end

local function applyScale()
	if not bud then
		return
	end
	local target = CompanionMath.scaleFor(stageNow())
	if math.abs(target - currentScale) > 1e-3 then
		bud:ScaleTo(target)
		currentScale = target
	end
end

local function spawnBud(character: Model)
	destroyBud()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or character.Parent == nil then
		return
	end
	bud = buildBud()
	currentScale = 1
	budBase = root.CFrame * FOLLOW_OFFSET
	bud:PivotTo(budBase)
	bud.Parent = folder()
	applyScale()

	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not (bud and root.Parent) then
			return
		end
		bobClock += dt
		local target = root.CFrame * FOLLOW_OFFSET
		budBase = budBase:Lerp(target, 1 - math.exp(-FOLLOW_RATE * dt))
		bud:PivotTo(budBase * CFrame.new(0, math.sin(bobClock * 2.5) * 0.3, 0))
	end)
end

function CompanionController.Start()
	ModalController.register(MODAL, function(container)
		return CompanionPanel.build(container, StateController)
	end, "Grow Your Bud")

	HUDController.registerButton("right", {
		id = "Bud",
		text = "Bud",
		order = 40,
		onClick = function()
			if ModalController.getCurrentName() == MODAL then
				ModalController.close()
			else
				ModalController.open(MODAL)
			end
		end,
		badge = function()
			return if CompanionMath.canClaim(StateController.get("companion")) then "!" else nil
		end,
	})

	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(destroyBud)
	player.CharacterAdded:Connect(function(character)
		task.spawn(spawnBud, character)
	end)
	if player.Character then
		task.spawn(spawnBud, player.Character)
	end

	StateController.changed:Connect(function(path)
		if path == "*" or path == "companion" or path == "companion.stage" then
			applyScale()
		end
	end)
end

return CompanionController
