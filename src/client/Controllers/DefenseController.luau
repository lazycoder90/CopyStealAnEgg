--!nonstrict
-- Pertahanan di HUD: tombol Trap dan Shield (kiri), overlay "STUCK! N" saat terjebak Yolk Trap, dan
-- label "Shield" di atas Coop sendiri selama kubah aktif.
-- Catatan waktu: shieldReadyAt memakai Clock.now() server (os.time + offset admin Studio); klien memakai
-- os.time(), jadi hitung mundur bisa meleset hanya saat admin memajukan waktu di Studio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Logic.NumberFormat)
local PvpRules = require(Shared.Logic.PvpRules)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local HUDController = require(script.Parent.HUDController)
local StateController = require(script.Parent.StateController)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags
local LocalPlayer = Players.LocalPlayer

local DefenseController = {}

local SHIELD_COLOR = Color3.fromRGB(70, 160, 215)
local STUCK_COLOR = Color3.fromRGB(255, 150, 30)

local stuckGui, stuckLabel, shieldBillboard, shieldLabel
local stuckToken = 0

local function ownPlot(): Instance?
	local plots = workspace:FindFirstChild(Names.Plots)
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute(Attr.OwnerUserId) == LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function findHudButton(id: string): TextButton?
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("HUD")
	local stack = hud and hud:FindFirstChild("LeftStack")
	return stack and stack:FindFirstChild("Btn_" .. id)
end

local function placeTrap()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Titik di depan kaki pemain; server yang menempelkannya ke tanah.
	local pos = root.Position + root.CFrame.LookVector * 5 - Vector3.new(0, 3, 0)
	Net.send("PlaceTrap", pos)
end

local function trapPrice(): number
	return PvpRules.trapCost(StateController.get("lastIncomePerSec") or 0)
end

local function refreshButtons()
	local trap = findHudButton("Trap")
	if trap then
		local price = trapPrice()
		trap.TextSize = 15
		trap.Text = "Trap\n" .. NumberFormat.fmtMoney(price)
		Button.setDisabled(trap, (StateController.get("cash") or 0) < price)
	end
	local shield = findHudButton("Shield")
	if shield then
		local remaining = (StateController.get("shieldReadyAt") or 0) - os.time()
		shield.TextSize = 15
		if remaining > 0 then
			shield.Text = "Shield\n" .. NumberFormat.fmtTime(remaining)
		else
			shield.Text = "Shield\nReady"
		end
		Button.setDisabled(shield, remaining > 0)
	end
end

-- ===== STUCK =====

local function showStuck(seconds: number)
	stuckToken += 1
	local mine = stuckToken
	local endsAt = os.clock() + seconds
	stuckGui.Enabled = true
	task.spawn(function()
		while mine == stuckToken do
			local left = endsAt - os.clock()
			if left <= 0 then
				break
			end
			stuckLabel.Text = "STUCK! " .. math.ceil(left)
			task.wait(0.1)
		end
		if mine == stuckToken then
			stuckGui.Enabled = false
		end
	end)
end

-- ===== Label Shield di atas Coop =====

local function domeExists(): boolean
	for _, inst in CollectionService:GetTagged(Tags.Shield) do
		if inst:GetAttribute(Attr.OwnerUserId) == LocalPlayer.UserId then
			return true
		end
	end
	return false
end

local function refreshShieldMark()
	if not shieldBillboard then
		return
	end
	local plot = ownPlot()
	local floor = plot and plot:FindFirstChild(Names.PlotFloor)
	local untilAt = plot and plot:GetAttribute(Attr.ShieldUntil) or 0
	local active = floor ~= nil and untilAt > 0 and domeExists()
	if active then
		shieldBillboard.Adornee = floor
		local remaining = untilAt - os.time()
		shieldLabel.Text = if remaining > 0 and remaining <= 200
			then `Shield {remaining}s`
			else "Shield"
	end
	shieldBillboard.Enabled = active
end

function DefenseController.Start()
	HUDController.registerButton("left", {
		id = "Trap",
		text = "Trap",
		order = 40,
		color = Theme.Colors.Yolk,
		onClick = placeTrap,
	})
	HUDController.registerButton("left", {
		id = "Shield",
		text = "Shield",
		order = 41,
		color = SHIELD_COLOR,
		onClick = function()
			Net.send("ActivateShield")
		end,
	})

	Net.connect("Trapped", function(payload)
		if type(payload) == "table" and type(payload.seconds) == "number" and stuckGui then
			showStuck(payload.seconds)
		end
	end)

	StateController.changed:Connect(function(path)
		if
			path == "*"
			or path == "cash"
			or path == "lastIncomePerSec"
			or path == "shieldReadyAt"
		then
			refreshButtons()
		end
	end)
	CollectionService:GetInstanceAddedSignal(Tags.Shield):Connect(refreshShieldMark)
	CollectionService:GetInstanceRemovedSignal(Tags.Shield):Connect(refreshShieldMark)

	task.spawn(function()
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")

		stuckGui = UIBuilder.create("ScreenGui", {
			Name = "Stuck",
			ResetOnSpawn = false,
			DisplayOrder = 30,
			Enabled = false,
		})
		stuckLabel = UIBuilder.create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.35),
			Size = UDim2.fromOffset(460, 110),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextScaled = true,
			TextColor3 = STUCK_COLOR,
			Text = "STUCK!",
			Parent = stuckGui,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Brown }),
			},
		})
		stuckGui.Parent = playerGui

		shieldBillboard = UIBuilder.create("BillboardGui", {
			Name = "ShieldMark",
			ResetOnSpawn = false,
			Size = UDim2.fromOffset(180, 50),
			StudsOffset = Vector3.new(0, 24, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Enabled = false,
		})
		shieldLabel = UIBuilder.create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextScaled = true,
			TextColor3 = Theme.Colors.White,
			Text = "Shield",
			Parent = shieldBillboard,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 3, Color = SHIELD_COLOR }),
			},
		})
		shieldBillboard.Parent = playerGui

		while stuckGui.Parent do
			refreshButtons()
			refreshShieldMark()
			task.wait(1)
		end
	end)
end

return DefenseController
