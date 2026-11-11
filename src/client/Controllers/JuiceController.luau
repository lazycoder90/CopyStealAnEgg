--!nonstrict
-- Juice ringan: (a) "pop" label Cash saat uang naik, (b) Highlight berdenyut pada telur langka di
-- dekat pemain, (c) denyut ColorCorrection saat membawa telur (tanpa menyentuh FieldOfView karena
-- SpeedController yang memilikinya). Semua mati total di mode grafis rendah.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelFactory = require(Shared.ModelFactory)
local PolishConfig = require(Shared.Config.PolishConfig)
local Types = require(Shared.Types)

local CarryController = require(script.Parent.CarryController)
local GraphicsController = require(script.Parent.GraphicsController)
local StateController = require(script.Parent.StateController)

local JuiceController = {}

local cfg = PolishConfig.juice
local LocalPlayer = Players.LocalPlayer

local GLOW_NAME = "NBRareGlow"

-- (a) cash pop
local cashScale -- UIScale pada label Cash
local lastCash = nil
local lastPopAt = -10
local popTween

-- (b) highlight langka
local glows = {} -- model -> { highlight, tween }
local scanAccumulator = 0
local scanConn

-- (c) denyut membawa telur
local pulseEffect
local pulseConn

local function isLow(): boolean
	return GraphicsController.isLow()
end

---------------------------------------------------------------- cash pop
local function findCashLabel()
	local gui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD", 30)
	local bottom = gui and gui:WaitForChild("BottomLeft", 10)
	local label = bottom and bottom:WaitForChild("Cash", 10)
	if label and label:IsA("TextLabel") then
		local scale = label:FindFirstChild("NBCashPop")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "NBCashPop"
			scale.Parent = label
		end
		cashScale = scale
	end
end

local function onCash()
	local cash = StateController.get("cash")
	if type(cash) ~= "number" then
		return
	end
	local previous = lastCash
	lastCash = cash
	if previous == nil or cash <= previous or not cashScale or isLow() then
		return
	end
	if cash - previous < cash * cfg.cashMinFraction then
		return
	end
	local now = os.clock()
	if now - lastPopAt < cfg.cashThrottle then
		return
	end
	lastPopAt = now
	if popTween then
		popTween:Cancel()
	end
	cashScale.Scale = 1
	popTween = TweenService:Create(
		cashScale,
		TweenInfo.new(
			cfg.cashPopSeconds / 2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0,
			true
		),
		{ Scale = cfg.cashPopScale }
	)
	popTween:Play()
end

---------------------------------------------------------------- highlight langka
local function removeGlow(model)
	local entry = glows[model]
	if not entry then
		return
	end
	glows[model] = nil
	entry.tween:Cancel()
	entry.highlight:Destroy()
end

local function clearGlows()
	for model in glows do
		removeGlow(model)
	end
end

local function addGlow(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = GLOW_NAME
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = ModelFactory.rarityColor(model:GetAttribute(Types.Attr.Rarity))
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ OutlineTransparency = 0.7 }
	)
	tween:Play()
	glows[model] = { highlight = highlight, tween = tween }
end

local function scanEggs()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		clearGlows()
		return
	end
	local origin = root.Position
	local radiusSq = cfg.rareRadius * cfg.rareRadius
	local count = 0
	local keep = {}
	for _, model in CollectionService:GetTagged(Types.Tags.WorldEgg) do
		if count >= cfg.rareMaxHighlights then
			break
		end
		local rarity = model:IsA("Model") and model:GetAttribute(Types.Attr.Rarity)
		if
			type(rarity) == "number"
			and rarity >= cfg.rareMinRarity
			and model:IsDescendantOf(workspace)
		then
			local pivot = model:GetPivot().Position
			local delta = pivot - origin
			if delta:Dot(delta) <= radiusSq then
				keep[model] = true
				count += 1
				if not glows[model] then
					addGlow(model)
				end
			end
		end
	end
	for model in glows do
		if not keep[model] then
			removeGlow(model)
		end
	end
end

---------------------------------------------------------------- denyut membawa telur
local function stopPulse()
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
	if pulseEffect then
		pulseEffect.Saturation = 0
		pulseEffect.Contrast = 0
		pulseEffect.Enabled = false
	end
end

local function startPulse()
	if pulseConn or isLow() then
		return
	end
	pulseEffect.Enabled = true
	local twoPi = math.pi * 2
	pulseConn = RunService.Heartbeat:Connect(function()
		local wave = 0.5 + 0.5 * math.sin(os.clock() * twoPi * cfg.carryPulseHz)
		pulseEffect.Saturation = cfg.carrySaturation * wave
		pulseEffect.Contrast = cfg.carryContrast * wave
	end)
end

local function onCarryChanged(carrying: boolean)
	if carrying then
		startPulse()
	else
		stopPulse()
	end
end

local function onGraphicsChanged(low: boolean)
	if low then
		clearGlows()
		stopPulse()
		if cashScale then
			cashScale.Scale = 1
		end
	elseif CarryController.isCarrying() then
		startPulse()
	end
end

function JuiceController.Start()
	pulseEffect = Instance.new("ColorCorrectionEffect")
	pulseEffect.Name = "NBCarryPulse"
	pulseEffect.Enabled = false
	pulseEffect.Parent = Lighting

	StateController.changed:Connect(function(path)
		if path == "cash" or path == "*" then
			onCash()
		end
	end)
	lastCash = StateController.get("cash")

	CarryController.changed:Connect(onCarryChanged)
	GraphicsController.changed:Connect(onGraphicsChanged)

	scanConn = RunService.Heartbeat:Connect(function(dt)
		scanAccumulator += dt
		if scanAccumulator < cfg.rareScanSeconds then
			return
		end
		scanAccumulator = 0
		if isLow() then
			return
		end
		scanEggs()
	end)

	task.spawn(findCashLabel)
end

-- Pembersihan penuh (hot reload / uji).
function JuiceController.Destroy()
	if scanConn then
		scanConn:Disconnect()
		scanConn = nil
	end
	clearGlows()
	stopPulse()
	if popTween then
		popTween:Cancel()
	end
	if cashScale then
		cashScale:Destroy()
		cashScale = nil
	end
	if pulseEffect then
		pulseEffect:Destroy()
		pulseEffect = nil
	end
end

return JuiceController
