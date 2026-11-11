--!nonstrict
-- EggResetService: Egg Reset global tiap 10 menit (waktu-game) + pengumuman spawn telur langka dan hatch langka.
-- Hitung mundur dikirim ke klien (remote EggReset {remaining}); saat 0: "ALL EGGS RESET!" lalu EggSpawnService.resetAll().
-- Spawn diumumkan lewat buffer 1 detik agar yang paling langka didahulukan dan maksimal N per batch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local EventsConfig = require(Shared.Config.EventsConfig)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local EggSpawnService = require(script.Parent.EggSpawnService)

local EggResetService = {}

local cfg = EventsConfig.eggReset
local ann = EventsConfig.announce

local timer = cfg.intervalSeconds
local sinceBroadcast = 0
local startedAt = os.clock()
local buffer = {} -- spawn langka menunggu flush
local flushScheduled = false
local seq = 0
local log = {} -- teks pengumuman terakhir (untuk uji)

local function sendAnnouncement(segments)
	local parts = {}
	for _, seg in segments do
		table.insert(parts, seg.text)
	end
	table.insert(log, table.concat(parts))
	while #log > ann.logSize do
		table.remove(log, 1)
	end
	AnnouncementService.broadcast(segments)
end

local function zoneSegment(zoneIndex: number)
	local zone = Zones.get(zoneIndex)
	return AnnouncementService.text(zone.name, zone.accentRgb)
end

local function flush()
	flushScheduled = false
	local batch = buffer
	buffer = {}
	table.sort(batch, function(a, b)
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return a.seq < b.seq
	end)
	for i = 1, math.min(#batch, ann.maxPerBatch) do
		local item = batch[i]
		local creature = Creatures.get(item.speciesId)
		sendAnnouncement({
			AnnouncementService.text("A "),
			AnnouncementService.rarity(item.rarity),
			AnnouncementService.text(" " .. creature.name .. " Egg spawned in "),
			zoneSegment(item.zone),
			AnnouncementService.text("!"),
		})
	end
end

local function onSpawned(info)
	if os.clock() - startedAt < ann.bootIgnoreSeconds then
		return
	end
	if not Rarities.get(info.rarity).announce then
		return
	end
	seq += 1
	table.insert(buffer, {
		rarity = info.rarity,
		speciesId = info.speciesId,
		zone = info.zone,
		seq = seq,
	})
	if not flushScheduled then
		flushScheduled = true
		task.delay(ann.bufferSeconds, flush)
	end
end

local function onHatched(info)
	if not Rarities.get(info.rarity).announce then
		return
	end
	if info.rarity < EventsConfig.hatchAnnounceMinRarity then
		return
	end
	local creature = Creatures.get(info.speciesId)
	sendAnnouncement({
		AnnouncementService.text(Actors.getName(info.userId)),
		AnnouncementService.text(" hatched a "),
		AnnouncementService.rarity(info.rarity),
		AnnouncementService.text(" " .. creature.name .. "!"),
	})
end

local function broadcast()
	sinceBroadcast = 0
	Net.fireAll("EggReset", { remaining = math.max(0, timer) })
end

function EggResetService.resetNow()
	sendAnnouncement({ AnnouncementService.text("ALL EGGS RESET!") })
	local count = EggSpawnService.resetAll()
	timer = cfg.intervalSeconds
	broadcast()
	return count
end

function EggResetService.remaining(): number
	return timer
end

local function tick(dt: number)
	timer -= dt
	if timer <= 0 then
		EggResetService.resetNow()
		return
	end
	sinceBroadcast += dt
	if timer <= cfg.countdownBroadcastSeconds or sinceBroadcast >= cfg.broadcastEvery then
		broadcast()
	end
end

function EggResetService.Init()
	TestBridge.register("reset.now", EggResetService.resetNow)
	TestBridge.register("reset.remaining", EggResetService.remaining)
	TestBridge.register("reset.log", function()
		return table.clone(log)
	end)
	TestBridge.register("reset.clearLog", function()
		table.clear(log)
		return true
	end)
	-- Uji: atur waktu "Start" (os.clock) untuk jendela boot; mengembalikan nilai lama.
	TestBridge.register("reset.setStartedAt", function(value)
		local old = startedAt
		startedAt = value
		return old
	end)
	TestBridge.register("reset.setRemaining", function(value)
		local old = timer
		timer = value
		return old
	end)

	AdminService.register("reset", function()
		local count = EggResetService.resetNow()
		return `Egg Reset: {count} sarang di-roll ulang`
	end)
end

function EggResetService.Start()
	startedAt = os.clock()
	GameEvents.EggSpawned:Connect(onSpawned)
	GameEvents.EggHatched:Connect(onHatched)
	Clock.every1Hz(tick)

	Net.on("ClientReady", Check.args(), function(player)
		Net.fire("EggReset", player, { remaining = math.max(0, timer) })
	end)
end

return EggResetService
