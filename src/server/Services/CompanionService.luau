--!nonstrict
-- CompanionService: Bud (companion). Klaim stage, buff kumulatif (income aditif, speed), admin dan hook uji.
-- Progres quest dihitung QuestTracker. Data: data.companion = { stage, progress, claimed, elder? }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanionMath = require(Shared.Logic.CompanionMath)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local InvariantChecker = require(Systems.InvariantChecker)
local TestBridge = require(Systems.TestBridge)
local EventsConfig = require(Shared.Config.EventsConfig)

local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local QuestTracker = require(script.Parent.QuestTracker)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)

local CompanionService = {}

local function notify(userId: number, message: string, kind: string)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

-- Klaim hadiah stage saat ini. Mengembalikan ok, galat.
function CompanionService.claim(userId: number): (boolean, string?)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "no data"
	end
	local c = QuestTracker.companionOf(data)
	local stage = c.stage
	if CompanionMath.isClaimed(c, stage) then
		return false, "already claimed"
	end
	if not CompanionMath.isComplete(stage, c.progress) then
		return false, "quests incomplete"
	end
	-- Atomik (tanpa yield): tandai klaim, naikkan stage, replikasi.
	c.claimed[tostring(stage)] = true
	StateReplicator.set(userId, `companion.claimed.{stage}`, true)
	local nextStage = CompanionMath.nextStage(stage)
	if nextStage ~= stage then
		c.stage = nextStage
		StateReplicator.set(userId, "companion.stage", nextStage)
	end
	if stage == CompanionMath.maxStage then
		c.elder = true
		StateReplicator.set(userId, "companion.elder", true)
		notify(userId, "Your Bud is fully grown!", "success")
	else
		notify(userId, "Bud grew!", "success")
	end
	SpeedService.refresh(userId)
	return true
end

-- Admin: atur stage, bersihkan progres; stage di bawahnya dianggap sudah diklaim.
function CompanionService.setStage(userId: number, stage: number)
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	local c = QuestTracker.companionOf(data)
	c.stage = CompanionMath.clampStage(stage)
	c.progress = {}
	c.claimed = {}
	for s = 1, c.stage - 1 do
		c.claimed[tostring(s)] = true
	end
	c.elder = nil
	StateReplicator.set(userId, "companion", deepCopy(c))
	SpeedService.refresh(userId)
	return true
end

function CompanionService.Init()
	IncomeService.addBonus("companion", function(userId)
		local data = DataService.getByUserId(userId)
		return data and CompanionMath.incomeBonus(data.companion) or 0
	end)
	SpeedService.addMultiplier("companion", function(userId)
		local data = DataService.getByUserId(userId)
		return data and CompanionMath.speedMult(data.companion) or 1
	end)

	InvariantChecker.register("Companion", function(entry)
		local out = {}
		local c = entry.data.companion
		if type(c) ~= "table" then
			table.insert(out, "companion hilang")
			return out
		end
		if c.stage ~= CompanionMath.clampStage(c.stage) then
			table.insert(out, `stage tidak valid: {tostring(c.stage)}`)
			return out
		end
		for key in c.claimed or {} do
			local s = tonumber(key)
			if not s or s > c.stage or (s == c.stage and s ~= CompanionMath.maxStage) then
				table.insert(out, `claimed {key} tidak konsisten dengan stage {c.stage}`)
			end
		end
		if c.elder and not CompanionMath.isClaimed(c, CompanionMath.maxStage) then
			table.insert(out, "elder tanpa klaim stage 4")
		end
		for _, def in EventsConfig.stages do
			for _, quest in def.quests do
				local n = (c.progress or {})[quest.key]
				if n ~= nil and (type(n) ~= "number" or n < 0 or n > quest.target) then
					table.insert(out, `progres {quest.key} di luar rentang: {tostring(n)}`)
				end
			end
		end
		return out
	end)

	TestBridge.register("companion.state", function(userId)
		local data = DataService.getByUserId(userId)
		return data and deepCopy(QuestTracker.companionOf(data))
	end)
	TestBridge.register("companion.progress", function(userId, key, amount)
		return QuestTracker.addProgress(userId, key, amount)
	end)
	TestBridge.register("companion.claim", function(userId)
		local ok, err = CompanionService.claim(userId)
		return { ok = ok, err = err }
	end)

	AdminService.register("bud", function(player, args)
		local stage = tonumber(args[1])
		if not (stage and stage >= 1 and stage <= CompanionMath.maxStage) then
			return "Pakai: bud <1..4>"
		end
		CompanionService.setStage(player.UserId, stage)
		return `Bud stage = {stage}`
	end)
end

function CompanionService.Start()
	Net.on("ClaimCompanionStage", Check.args(), function(player)
		local ok, err = CompanionService.claim(player.UserId)
		if not ok and err then
			Net.fire("Notify", player, "Bud is not ready yet", "error")
		end
	end)
end

return CompanionService
