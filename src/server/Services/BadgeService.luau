--!nonstrict
-- BadgeService: badge dicatat di profil (data.badges[key] = true) dan, bila id config ~= 0, diberikan lewat
-- Roblox BadgeService:AwardBadge. Tidak pernah diberikan dua kali. Pemicu: event gameplay + polling 1 Hz.
-- Hook TestBridge: badge.award(userId, key), badge.list(userId).

local RobloxBadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BadgeConfig = require(Shared.Config.BadgeConfig)
local Net = require(Shared.Net.Net)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local BadgeService = {}

-- Mengembalikan true hanya pada pemberian pertama.
function BadgeService.award(userId: number, key: string): boolean
	local def = BadgeConfig.byKey[key]
	local data = DataService.getByUserId(userId)
	if not (def and data) or data.badges[key] == true then
		return false
	end
	data.badges[key] = true
	StateReplicator.set(userId, `badges.{key}`, true)

	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, `Badge: {def.name}!`, "success")
		if def.id ~= 0 then
			task.spawn(function()
				local ok, err = pcall(function()
					RobloxBadgeService:AwardBadge(userId, def.id)
				end)
				if not ok then
					warn(`[BadgeService] AwardBadge {key} gagal: {err}`)
				end
			end)
		end
	end
	return true
end

local function hasAnyTrue(map): boolean
	for _, value in map or {} do
		if value == true then
			return true
		end
	end
	return false
end

-- Pemicu berbasis kondisi data (polling 1 Hz).
local function pollEntry(entry)
	local userId, data = entry.userId, entry.data
	if not data.badges then
		return
	end
	if not data.badges.IndexZone and hasAnyTrue(data.index and data.index.zoneBonus) then
		BadgeService.award(userId, "IndexZone")
	end
	if not data.badges.RaceWinner and (data.trophies or 0) > 0 then
		BadgeService.award(userId, "RaceWinner")
	end
	if
		not data.badges.StarwhaleVisitor
		and data.starwhale
		and data.starwhale.relayFixed == true
	then
		BadgeService.award(userId, "StarwhaleVisitor")
	end
	if not data.badges.BudElder and data.companion and data.companion.elder == true then
		BadgeService.award(userId, "BudElder")
	end
end

function BadgeService.Init()
	TestBridge.register("badge.award", BadgeService.award)
	TestBridge.register("badge.list", function(userId)
		local data = DataService.getByUserId(userId)
		local list = {}
		for key, value in data and data.badges or {} do
			if value == true then
				table.insert(list, key)
			end
		end
		table.sort(list)
		return list
	end)
end

function BadgeService.Start()
	GameEvents.EggHatched:Connect(function(event)
		BadgeService.award(event.userId, "FirstHatch")
	end)
	GameEvents.EggPlaced:Connect(function(event)
		if event.stolen == true then
			BadgeService.award(event.userId, "FirstSteal")
		end
	end)
	GameEvents.ZoneChanged:Connect(function(event)
		if type(event.zone) ~= "number" then
			return
		end
		for _, rule in BadgeConfig.zoneBadges do
			if event.zone >= rule.zone then
				BadgeService.award(event.userId, rule.key)
			end
		end
	end)
	Clock.every1Hz(function()
		for _, entry in DataService.all() do
			if not entry.virtual then
				pollEntry(entry)
			end
		end
	end)
end

return BadgeService
