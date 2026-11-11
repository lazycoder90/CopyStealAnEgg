--!nonstrict
-- TutorialService (docs/PLAN.md §4.22): data.tutorial = { step, done } plus bonus/baseline (disimpan di tabel yang sama).
-- Langkah: 1 grab, 2 bawa pulang (lewat Hearth Line), 3 place, 4 hatch, 5 reveal (otomatis 4 detik),
-- 6 upgrade Coop (bonus $1000 sekali), 7 Sprint Wheel (30 step), 8 selesai.
-- Polling memakai waktu nyata (Heartbeat), bukan Clock.timeScale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Formulas = require(Shared.Logic.Formulas)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local CarryService = require(script.Parent.CarryService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local TutorialService = {}

local LAST_STEP = 8
local REVEAL_SECONDS = 4
local BONUS_CASH = 1000
local NEWBIE_PROTECT_SECONDS = 300
local WHEEL_STEPS = 30
local POLL_INTERVAL = 0.25

local advanceAt = {} -- [userId] = os.clock() saat langkah 5 boleh lanjut
local pollAccumulator = 0

local function tutorialOf(userId: number)
	local data = DataService.getByUserId(userId)
	return data and data.tutorial, data
end

local function notify(userId: number, message: string)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("Notify", player, message, "success")
	end
end

function TutorialService.isActive(userId: number): boolean
	local tutorial = tutorialOf(userId)
	return tutorial ~= nil and tutorial.done ~= true
end

function TutorialService.getStep(userId: number): number?
	local tutorial = tutorialOf(userId)
	return tutorial and tutorial.step
end

local setStep

-- Aksi saat langkah dimulai (dipanggil tiap kali masuk langkah, termasuk saat join/resume).
local function enterStep(userId: number, step: number)
	local tutorial, data = tutorialOf(userId)
	if not tutorial then
		return
	end
	advanceAt[userId] = nil
	if step == 5 then
		advanceAt[userId] = os.clock() + REVEAL_SECONDS
		notify(userId, "Your creatures earn cash!")
	elseif step == 6 then
		-- Bonus hanya sekali: bendera disimpan di profil sehingga tidak berulang setelah rejoin.
		if not tutorial.bonus then
			tutorial.bonus = true
			CurrencyService.add(userId, "cash", BONUS_CASH)
			notify(userId, "Bonus: $1K to upgrade your Coop!")
		end
	elseif step == 7 then
		if type(tutorial.baseline) ~= "number" then
			tutorial.baseline = data.speedBase
		end
	end
end

function setStep(userId: number, step: number)
	local tutorial = tutorialOf(userId)
	if not tutorial or tutorial.done then
		return
	end
	step = math.clamp(step, 1, LAST_STEP)
	tutorial.step = step
	StateReplicator.set(userId, "tutorial.step", step)
	if step >= LAST_STEP then
		tutorial.done = true
		StateReplicator.set(userId, "tutorial.done", true)
		advanceAt[userId] = nil
		return
	end
	enterStep(userId, step)
end

function TutorialService.skip(userId: number)
	local tutorial = tutorialOf(userId)
	if not tutorial then
		return false
	end
	tutorial.step = LAST_STEP
	tutorial.done = true
	advanceAt[userId] = nil
	local data = DataService.getByUserId(userId)
	if data and (data.newbieProtectUntil or 0) > 0 then
		data.newbieProtectUntil = 0 -- melewati tutorial berarti melepas proteksi newbie
		StateReplicator.set(userId, "newbieProtectUntil", 0)
	end
	StateReplicator.set(userId, "tutorial.step", LAST_STEP)
	StateReplicator.set(userId, "tutorial.done", true)
	return true
end

-- Admin/uji: ulang dari awal atau loncat ke langkah tertentu.
function TutorialService.reset(userId: number, step: number?)
	local tutorial = tutorialOf(userId)
	if not tutorial then
		return false
	end
	tutorial.done = false
	tutorial.bonus = nil
	tutorial.baseline = nil
	StateReplicator.set(userId, "tutorial.done", false)
	setStep(userId, step or 1)
	return true
end

local function pollOne(userId: number)
	local tutorial, data = tutorialOf(userId)
	if not tutorial or tutorial.done then
		return
	end
	local step = tutorial.step
	if step == 2 then
		local root = Actors.getRoot(userId)
		if not CarryService.isCarrying(userId) then
			setStep(userId, 1) -- telur hilang (jatuh/tertangkap): ulangi dari awal, tidak boleh macet
		elseif root and root.Position.Z < Layout.hearthLineZ then
			setStep(userId, 3)
		end
	elseif step == 3 then
		if not CarryService.isCarrying(userId) then
			setStep(userId, 1)
		end
	elseif step == 5 then
		if advanceAt[userId] and os.clock() >= advanceAt[userId] then
			setStep(userId, 6)
		end
	elseif step == 6 then
		if (data.plotExpansion or 0) >= 1 then
			setStep(userId, 7)
		end
	elseif step == 7 then
		local baseline = tutorial.baseline or data.speedBase
		if
			data.speedBase
			>= baseline + WHEEL_STEPS * Formulas.wheelGainPerStep(data.wheelLevel)
		then
			setStep(userId, LAST_STEP)
		end
	end
end

function TutorialService.Init()
	PlayerLifecycle.onJoin("TutorialService", 100, function(ctx)
		local data = ctx.data
		if type(data.tutorial) ~= "table" then
			data.tutorial = { step = 1, done = false }
		end
		local tutorial = data.tutorial
		if
			not tutorial.done
			and ((data.stats and data.stats.hatched or 0) > 0 or tutorial.step >= LAST_STEP)
		then
			tutorial.done = true
			tutorial.step = LAST_STEP
		end
		if tutorial.done then
			return
		end
		if tutorial.step == 1 and data.newbieProtectUntil == 0 then
			data.newbieProtectUntil = Clock.now() + NEWBIE_PROTECT_SECONDS
			StateReplicator.set(ctx.userId, "newbieProtectUntil", data.newbieProtectUntil)
		end
		-- Telur yang dibawa tidak bertahan lewat sesi: langkah 2/3 kembali ke 1.
		if tutorial.step == 2 or tutorial.step == 3 then
			tutorial.step = 1
		end
		enterStep(ctx.userId, tutorial.step)
	end)
	PlayerLifecycle.onLeaving("TutorialService", 100, function(ctx)
		advanceAt[ctx.userId] = nil
	end)

	TestBridge.register("tutorial.step", function(userId)
		local tutorial = tutorialOf(userId)
		return tutorial and { step = tutorial.step, done = tutorial.done }
	end)
	TestBridge.register("tutorial.set", function(userId, step)
		return TutorialService.reset(userId, step)
	end)

	AdminService.register("tutorial", function(player, args)
		local arg = string.lower(args[1] or "")
		local userId = player.UserId
		if arg == "skip" then
			TutorialService.skip(userId)
			return "Tutorial dilewati"
		elseif arg == "reset" then
			TutorialService.reset(userId, 1)
			return "Tutorial diulang"
		end
		local step = tonumber(arg)
		if step and step % 1 == 0 and step >= 1 and step <= LAST_STEP then
			TutorialService.reset(userId, step)
			return `Tutorial langkah {step}`
		end
		return "Pakai: tutorial skip|reset|<1..8>"
	end)
end

function TutorialService.Start()
	GameEvents.EggGrabbed:Connect(function(payload)
		local tutorial = tutorialOf(payload.userId)
		if tutorial and not tutorial.done and tutorial.step == 1 then
			setStep(payload.userId, 2)
		end
	end)
	GameEvents.EggPlaced:Connect(function(payload)
		local tutorial = tutorialOf(payload.userId)
		if tutorial and not tutorial.done and (tutorial.step == 2 or tutorial.step == 3) then
			setStep(payload.userId, 4)
		end
	end)
	GameEvents.EggHatched:Connect(function(payload)
		local tutorial = tutorialOf(payload.userId)
		if tutorial and not tutorial.done and tutorial.step == 4 then
			setStep(payload.userId, 5)
		end
	end)

	Net.on("TutorialAck", Check.args(Check.enum({ "skip" })), function(player)
		TutorialService.skip(player.UserId)
	end)

	RunService.Heartbeat:Connect(function(dt)
		pollAccumulator += dt
		if pollAccumulator < POLL_INTERVAL then
			return
		end
		pollAccumulator = 0
		for _, entry in DataService.all() do
			pollOne(entry.userId)
		end
	end)
end

return TutorialService
