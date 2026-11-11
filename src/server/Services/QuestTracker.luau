--!nonstrict
-- QuestTracker: menghitung progres quest Bud dari GameEvents. Hanya quest stage SAAT INI yang bertambah
-- (dibatasi target). Progres disimpan di data.companion.progress[questKey] dan direplikasi per kunci.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionMath = require(Shared.Logic.CompanionMath)

local Systems = script.Parent.Parent.Systems
local GameEvents = require(Systems.GameEvents)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local QuestTracker = {}

-- Pastikan struktur companion lengkap (profil lama bisa kurang field).
function QuestTracker.companionOf(data)
	local c = data.companion
	if type(c) ~= "table" then
		c = { stage = 1, progress = {}, claimed = {} }
		data.companion = c
	end
	c.stage = CompanionMath.clampStage(c.stage)
	c.progress = c.progress or {}
	c.claimed = c.claimed or {}
	return c
end

-- Menambah progres satu quest (kunci harus milik stage sekarang). Mengembalikan jumlah baru atau nil.
function QuestTracker.addProgress(userId: number, questKey: string, amount: number): number?
	local data = DataService.getByUserId(userId)
	if not data then
		return nil
	end
	local c = QuestTracker.companionOf(data)
	if CompanionMath.isClaimed(c, c.stage) then
		return nil
	end
	for _, quest in CompanionMath.questsFor(c.stage) do
		if quest.key == questKey then
			local current = c.progress[quest.key] or 0
			local updated = CompanionMath.add(current, quest, amount)
			if updated ~= current then
				c.progress[quest.key] = updated
				StateReplicator.set(userId, `companion.progress.{quest.key}`, updated)
			end
			return updated
		end
	end
	return nil
end

-- Memproses satu event gameplay untuk satu pemain.
function QuestTracker.record(userId: number, event: string, payload)
	local data = DataService.getByUserId(userId)
	if not data then
		return
	end
	local c = QuestTracker.companionOf(data)
	for _, quest in CompanionMath.questsFor(c.stage) do
		if CompanionMath.matches(quest, event, payload) then
			QuestTracker.addProgress(userId, quest.key, 1)
		end
	end
end

function QuestTracker.Start()
	GameEvents.EggGrabbed:Connect(function(p)
		QuestTracker.record(p.userId, "EggGrabbed", p)
	end)
	GameEvents.EggPlaced:Connect(function(p)
		QuestTracker.record(p.userId, "EggPlaced", p)
	end)
	GameEvents.EggHatched:Connect(function(p)
		QuestTracker.record(p.userId, "EggHatched", p)
	end)
end

return QuestTracker
