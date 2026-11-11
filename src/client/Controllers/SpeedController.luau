--!nonstrict
-- Slow Mode (tombol HUD kiri) dan FOV yang melebar halus saat WalkSpeed tinggi (> 40).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local HUDController = require(script.Parent.HUDController)
local StateController = require(script.Parent.StateController)

local SpeedController = {}

local BASE_FOV = 70
local MAX_FOV = 85
local FOV_START_SPEED = 40 -- WalkSpeed awal pelebaran
local FOV_FULL_SPEED = 100 -- WalkSpeed pelebaran penuh
local SLOW_CAP = 20

local function slowMode(): boolean
	return StateController.get("settings.slowMode") == true
end

local function registerButton()
	local on = slowMode()
	HUDController.registerButton("left", {
		id = "SlowMode",
		text = if on then "Slow: ON" else "Slow",
		order = 30,
		color = if on then Theme.Colors.Mint else Theme.Colors.Yolk,
		onClick = function()
			Net.send("SetSlowMode", not slowMode())
		end,
	})
end

local function currentWalkSpeed(): number
	local speed = StateController.get("speedEffective") or StateController.get("speedBase") or 0
	local walk = Formulas.walkSpeed(speed)
	if slowMode() then
		walk = math.min(walk, SLOW_CAP)
	end
	return walk
end

function SpeedController.Start()
	registerButton()
	StateController.changed:Connect(function(path)
		if path == "*" or path == "settings.slowMode" or path == "settings" then
			registerButton()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = math.clamp(
			(currentWalkSpeed() - FOV_START_SPEED) / (FOV_FULL_SPEED - FOV_START_SPEED),
			0,
			1
		)
		local target = BASE_FOV + (MAX_FOV - BASE_FOV) * t
		local fov = camera.FieldOfView
		if math.abs(fov - target) > 0.05 then
			camera.FieldOfView = fov + (target - fov) * math.min(1, dt * 3)
		end
	end)
end

return SpeedController
