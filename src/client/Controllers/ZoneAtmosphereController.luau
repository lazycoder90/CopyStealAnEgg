--!nonstrict
-- Atmosfer per zona: efek Lighting lokal (Atmosphere, ColorCorrection, Bloom, SunRays) yang di-tween
-- 2 detik ke parameter zona tempat pemain berdiri (4 Hz). Tidak menyentuh ClockTime/Brightness/Ambient
-- karena itu milik siklus siang/malam server. Mode grafis rendah mematikan bloom/sunrays/atmosfer.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AtmosphereMath = require(Shared.Logic.AtmosphereMath)
local Layout = require(Shared.Config.Layout)
local PolishConfig = require(Shared.Config.PolishConfig)

local GraphicsController = require(script.Parent.GraphicsController)

local ZoneAtmosphereController = {}

local cfg = PolishConfig.atmosphere
local LocalPlayer = Players.LocalPlayer

local atmosphere, grade, bloom, rays
local tweens = {}
local currentZone = -1 -- -1 = belum diinisialisasi, 0 = hub
local heartbeatConn, lowConn
local accumulator = 0

local function color(rgb): Color3
	return Color3.fromRGB(
		math.floor(rgb[1] + 0.5),
		math.floor(rgb[2] + 0.5),
		math.floor(rgb[3] + 0.5)
	)
end

local function cancelTweens()
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
end

local function play(instance: Instance, goal, info)
	local tween = TweenService:Create(instance, info, goal)
	table.insert(tweens, tween)
	tween:Play()
end

local function applyParams(p, instant: boolean)
	cancelTweens()
	local info = TweenInfo.new(
		if instant then 0 else cfg.tweenSeconds,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	play(atmosphere, {
		Color = color(p.haze),
		Decay = color(p.haze),
		Density = p.hazeDensity,
		Offset = p.hazeOffset,
		Glare = p.glare,
	}, info)
	play(grade, {
		TintColor = color(p.tint),
		Brightness = p.brightness,
		Contrast = p.contrast,
		Saturation = p.saturation,
	}, info)
	play(bloom, {
		Intensity = p.bloomIntensity,
		Size = p.bloomSize,
		Threshold = p.bloomThreshold,
	}, info)
	play(rays, { Intensity = p.sunRays }, info)
end

local function applyLowState()
	local isLow = GraphicsController.isLow()
	bloom.Enabled = not isLow
	rays.Enabled = not isLow
	atmosphere.Parent = if isLow then nil else Lighting
end

local function zoneOfCharacter(): number
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return currentZone
	end
	return Layout.zoneAtZ(root.Position.Z) or 0
end

function ZoneAtmosphereController.Start()
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "NBZoneAtmosphere"
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "NBZoneGrade"
	bloom = Instance.new("BloomEffect")
	bloom.Name = "NBZoneBloom"
	rays = Instance.new("SunRaysEffect")
	rays.Name = "NBZoneRays"
	rays.Spread = 0.6
	grade.Parent = Lighting
	bloom.Parent = Lighting
	rays.Parent = Lighting
	atmosphere.Parent = Lighting

	applyParams(AtmosphereMath.hub(), true)
	currentZone = 0
	applyLowState()

	lowConn = GraphicsController.changed:Connect(applyLowState)
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / cfg.updateHz then
			return
		end
		accumulator = 0
		local zone = zoneOfCharacter()
		if zone ~= currentZone then
			currentZone = zone
			applyParams(AtmosphereMath.forZone(if zone == 0 then nil else zone), false)
		end
	end)
end

-- Pembersihan (dipakai uji manual / hot reload).
function ZoneAtmosphereController.Destroy()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if lowConn then
		lowConn:Disconnect()
		lowConn = nil
	end
	cancelTweens()
	for _, inst in { atmosphere, grade, bloom, rays } do
		inst:Destroy()
	end
end

return ZoneAtmosphereController
