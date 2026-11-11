--!nonstrict
-- SpeedService: stat Speed -> WalkSpeed. effectiveSpeed = speedBase x pengali (Trail, dll) x potion.
-- Slow Mode membatasi WalkSpeed <= 20. WalkSpeed diterapkan saat karakter muncul dan saat nilai
-- target berubah (dicek 2 Hz waktu nyata). Nilai yang tidak berubah TIDAK ditimpa ulang, sehingga
-- sistem lain yang sengaja menahan WalkSpeed (stun/trap) tidak dibatalkan; panggil
-- SpeedService.refresh(userId) setelah stun selesai untuk memulihkan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Maid = require(Shared.Util.Maid)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local SpeedService = {}

local SLOW_MODE_CAP = 20
local CHECK_INTERVAL = 0.5
local RESEND_EVERY = 10 -- siklus cek; speedEffective dikirim ulang tiap ~5 detik (aman terhadap resync)

local multipliers = {} -- name -> fn(userId) -> number
local applied = {} -- [userId] = { humanoid, walk }
local lastEffective = {} -- [userId] = number
local maids = {} -- [userId] = Maid
local cycle = 0

-- Pengali tambahan (mis. Trail). fn(userId) -> number >= 0.
function SpeedService.addMultiplier(name: string, fn: (number) -> number)
	multipliers[name] = fn
end

local function multiplierFor(userId: number): number
	local total = 1
	for _, fn in multipliers do
		local ok, value = pcall(fn, userId)
		if ok and type(value) == "number" and value == value and value > 0 then
			total *= value
		end
	end
	return total
end

function SpeedService.getEffectiveSpeed(userId: number): number
	local data = DataService.getByUserId(userId)
	if not data then
		return 0
	end
	local potion = (data.boosts and data.boosts.speed2xUntil or 0) > Clock.now()
	return Formulas.effectiveSpeed(data.speedBase, multiplierFor(userId), false, potion)
end

function SpeedService.getWalkSpeed(userId: number): number
	local data = DataService.getByUserId(userId)
	if not data then
		return 16
	end
	local walk = Formulas.walkSpeed(SpeedService.getEffectiveSpeed(userId))
	if data.settings and data.settings.slowMode then
		walk = math.min(walk, SLOW_MODE_CAP)
	end
	return walk
end

local function apply(userId: number, force: boolean?)
	local data = DataService.getByUserId(userId)
	if not data then
		return
	end
	local effective = SpeedService.getEffectiveSpeed(userId)
	if lastEffective[userId] ~= effective then
		lastEffective[userId] = effective
		StateReplicator.set(userId, "speedEffective", effective)
	end

	local humanoid = Actors.getHumanoid(userId)
	if not humanoid then
		applied[userId] = nil
		return
	end
	local walk = SpeedService.getWalkSpeed(userId)
	local record = applied[userId]
	if force or not record or record.humanoid ~= humanoid or record.walk ~= walk then
		humanoid.WalkSpeed = walk
		applied[userId] = { humanoid = humanoid, walk = walk }
	end
end

-- Terapkan ulang segera (dipanggil setelah perubahan speed/trail/slow mode atau akhir stun).
function SpeedService.refresh(userId: number)
	apply(userId, true)
end

function SpeedService.setSlowMode(userId: number, enabled: boolean)
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	data.settings.slowMode = enabled
	StateReplicator.set(userId, "settings.slowMode", enabled)
	apply(userId, true)
	return true
end

function SpeedService.Init()
	PlayerLifecycle.onJoin("SpeedService", 100, function(ctx)
		local maid = Maid.new()
		maids[ctx.userId] = maid
		if ctx.player then
			maid:Give(ctx.player.CharacterAdded:Connect(function(character)
				character:WaitForChild("Humanoid", 5)
				applied[ctx.userId] = nil
				apply(ctx.userId, true)
			end))
		end
		applied[ctx.userId] = nil
		lastEffective[ctx.userId] = nil
		apply(ctx.userId, true)
	end)
	-- order 1100: setelah snapshot StateReplicator (1000) agar nilai pertama sampai ke klien.
	PlayerLifecycle.onJoin("SpeedService.replicate", 1100, function(ctx)
		StateReplicator.set(
			ctx.userId,
			"speedEffective",
			SpeedService.getEffectiveSpeed(ctx.userId)
		)
	end)
	PlayerLifecycle.onLeaving("SpeedService", 100, function(ctx)
		local maid = maids[ctx.userId]
		if maid then
			maid:Clean()
			maids[ctx.userId] = nil
		end
		applied[ctx.userId] = nil
		lastEffective[ctx.userId] = nil
	end)

	TestBridge.register("speed.info", function(userId)
		local humanoid = Actors.getHumanoid(userId)
		return {
			effective = SpeedService.getEffectiveSpeed(userId),
			walk = SpeedService.getWalkSpeed(userId),
			humanoidWalkSpeed = humanoid and humanoid.WalkSpeed,
		}
	end)
	TestBridge.register("speed.refresh", function(userId)
		SpeedService.refresh(userId)
		return true
	end)
	TestBridge.register("speed.setSlow", SpeedService.setSlowMode)
end

function SpeedService.Start()
	Net.on("SetSlowMode", Check.args(Check.bool), function(player, enabled)
		SpeedService.setSlowMode(player.UserId, enabled)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < CHECK_INTERVAL then
			return
		end
		acc = 0
		cycle += 1
		local resend = cycle % RESEND_EVERY == 0
		for _, entry in DataService.all() do
			if resend then
				lastEffective[entry.userId] = nil
			end
			apply(entry.userId, false)
		end
	end)
end

return SpeedService
