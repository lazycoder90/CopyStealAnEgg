--!nonstrict
-- RaceController (Dash Derby): terima RaceState, tombol HUD "Race" (badge hitung mundur), panel RaceHud saat Open,
-- kartu RacePodium saat Closed, dan Beam kuning dari pemain ke gerbang berikutnya (hanya saat Open).
-- Waktu dari server = sisa detik; klien menghitung mundur sendiri memakai os.clock sejak paket terakhir.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RaceMath = require(Shared.Logic.RaceMath)
local Types = require(Shared.Types)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent.UI
local UIBuilder = require(UI.UIBuilder)
local RaceHud = require(UI.Screens.RaceHud)
local RacePodium = require(UI.Screens.RacePodium)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)

local Attr, Tags = Types.Attr, Types.Tags
local LocalPlayer = Players.LocalPlayer

local RaceController = {}

local BEAM_INTERVAL = 0.25
local BEAM_COLOR = Color3.fromRGB(255, 214, 64)

local state = nil -- RaceStatePayload terakhir
local receivedAt = 0
local lastPhase = nil
local gui, hud
local closePodium = nil
local beamMaid = nil
local beamTarget = nil -- indeks gerbang yang sedang ditunjuk
local beamRoot = nil

local function remainingNow(): number
	if not state then
		return 0
	end
	return math.max(0, state.remaining - (os.clock() - receivedAt))
end

local function clock(seconds: number): string
	local total = math.ceil(seconds)
	return string.format("%d:%02d", total // 60, total % 60)
end

-- Badge tombol HUD: hitung mundur saat Countdown, "OPEN m:ss" saat Open, selain itu kosong.
local function badge()
	if not state then
		return nil
	end
	if state.phase == "Countdown" then
		return clock(remainingNow())
	elseif state.phase == "Open" then
		return "OPEN " .. clock(remainingNow())
	end
	return nil
end

local function onButtonClick()
	if not state then
		return
	end
	local zone = state.zoneName or "a far lane"
	if state.phase == "Countdown" then
		NotificationController.push(
			`Dash Derby in {zone} starts in {clock(remainingNow())}`,
			"info"
		)
	elseif state.phase == "Open" then
		NotificationController.push(`Race open in {zone}! {clock(remainingNow())} left`, "success")
	else
		NotificationController.push(`Next Dash Derby in about {clock(remainingNow())}`, "info")
	end
end

-- ===== Beam ke gerbang berikutnya =====

local function clearBeam()
	if beamMaid then
		beamMaid:Clean()
		beamMaid = nil
	end
	beamTarget = nil
	beamRoot = nil
end

local function findGate(index: number): BasePart?
	for _, part in CollectionService:GetTagged(Tags.RaceGate) do
		if part:IsA("BasePart") and part:GetAttribute(Attr.GateIndex) == index then
			return part
		end
	end
	return nil
end

local function nextGateIndex(): number
	local attempt = state and state.myAttempt
	if attempt then
		return math.min(attempt.checkpoint + 1, RaceMath.finishIndex)
	end
	return 0
end

local function updateBeam()
	if not state or state.phase ~= "Open" then
		clearBeam()
		return
	end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		clearBeam()
		return
	end
	local index = nextGateIndex()
	local gate = findGate(index)
	if not gate then
		clearBeam()
		return
	end
	if beamMaid and beamTarget == index and beamRoot == root and gate.Parent then
		return
	end
	clearBeam()
	local maid = Maid.new()
	local from = UIBuilder.create("Attachment", { Name = "RaceBeamFrom", Parent = root })
	local to = UIBuilder.create("Attachment", { Name = "RaceBeamTo", Parent = gate })
	local beam = UIBuilder.create("Beam", {
		Name = "RaceBeam",
		Attachment0 = from,
		Attachment1 = to,
		Color = ColorSequence.new(BEAM_COLOR),
		Width0 = 0.5,
		Width1 = 0.5,
		LightEmission = 1,
		FaceCamera = true,
		Segments = 1,
		Parent = from,
	})
	maid:Give(from)
	maid:Give(to)
	maid:Give(beam)
	beamMaid = maid
	beamTarget = index
	beamRoot = root
end

-- ===== Penanganan state =====

local function showPodium(payload)
	if closePodium then
		closePodium()
	end
	if payload.podium and #payload.podium > 0 then
		closePodium = RacePodium.show(gui, payload, function()
			closePodium = nil
		end)
	else
		NotificationController.push("Nobody finished the Dash Derby.", "info")
	end
end

local function onState(payload)
	if type(payload) ~= "table" or type(payload.phase) ~= "string" then
		return
	end
	state = payload
	receivedAt = os.clock()
	if payload.phase == "Closed" and lastPhase ~= "Closed" and gui then
		showPodium(payload)
	end
	lastPhase = payload.phase
	if hud then
		hud:setState(payload, receivedAt)
	end
	updateBeam()
	HUDController.refreshBadges()
end

function RaceController.Start()
	HUDController.registerButton("right", {
		id = "race",
		text = "Race",
		order = 50,
		onClick = onButtonClick,
		badge = badge,
	})

	Net.connect("RaceState", onState)

	gui = UIBuilder.create("ScreenGui", {
		Name = "Race",
		ResetOnSpawn = false,
		DisplayOrder = 35,
	})
	hud = RaceHud.new(gui)
	if state then
		hud:setState(state, receivedAt)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if hud then
			hud:render()
		end
		acc += dt
		if acc >= BEAM_INTERVAL then
			acc = 0
			updateBeam()
		end
	end)

	task.spawn(function()
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return RaceController
