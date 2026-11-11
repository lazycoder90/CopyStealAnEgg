--!strict
-- Aturan Bud (companion): quest per stage, progres, klaim, dan buff kumulatif. Murni (Lune-testable).
-- companion = { stage = 1..4, progress = { [questKey] = n }, claimed = { ["1"] = true, ... }, elder = bool? }

local EventsConfig = require("../Config/EventsConfig")

local CompanionMath = {}

local MAX = EventsConfig.companion.maxStage

CompanionMath.maxStage = MAX

function CompanionMath.clampStage(stage: any): number
	local n = if type(stage) == "number" and stage == stage then math.floor(stage) else 1
	return math.clamp(n, 1, MAX)
end

function CompanionMath.questsFor(stage: number): { EventsConfig.Quest }
	local def = EventsConfig.stages[CompanionMath.clampStage(stage)]
	return def.quests
end

-- Apakah event (nama + payload) memenuhi syarat quest.
function CompanionMath.matches(quest: EventsConfig.Quest, event: string, payload: any): boolean
	if quest.event ~= event or type(payload) ~= "table" then
		return false
	end
	if quest.zone ~= nil and payload.zone ~= quest.zone then
		return false
	end
	if quest.minRarity ~= nil then
		if type(payload.rarity) ~= "number" or payload.rarity < quest.minRarity then
			return false
		end
	end
	if quest.stolen == true and payload.stolen ~= true then
		return false
	end
	return true
end

function CompanionMath.count(progress: { [string]: number }?, quest: EventsConfig.Quest): number
	local n = progress and progress[quest.key] or 0
	return math.clamp(if type(n) == "number" then n else 0, 0, quest.target)
end

-- Jumlah baru setelah menambah `amount` (dibatasi target).
function CompanionMath.add(current: number, quest: EventsConfig.Quest, amount: number): number
	return math.min(quest.target, math.max(0, current) + amount)
end

function CompanionMath.isComplete(stage: number, progress: { [string]: number }?): boolean
	for _, quest in CompanionMath.questsFor(stage) do
		if CompanionMath.count(progress, quest) < quest.target then
			return false
		end
	end
	return true
end

function CompanionMath.isClaimed(companion: any, stage: number): boolean
	return type(companion) == "table"
		and type(companion.claimed) == "table"
		and companion.claimed[tostring(stage)] == true
end

-- Bisa diklaim: quest stage sekarang lengkap dan belum diklaim.
function CompanionMath.canClaim(companion: any): boolean
	if type(companion) ~= "table" then
		return false
	end
	local stage = CompanionMath.clampStage(companion.stage)
	return not CompanionMath.isClaimed(companion, stage)
		and CompanionMath.isComplete(stage, companion.progress)
end

function CompanionMath.nextStage(stage: number): number
	return math.min(CompanionMath.clampStage(stage) + 1, MAX)
end

-- Total bonus income aditif dari semua stage yang sudah diklaim.
function CompanionMath.incomeBonus(companion: any): number
	local total = 0
	for stage, def in EventsConfig.stages do
		if CompanionMath.isClaimed(companion, stage) then
			total += def.incomeBonus
		end
	end
	return total
end

-- Pengali speed kumulatif dari stage yang sudah diklaim.
function CompanionMath.speedMult(companion: any): number
	local total = 1
	for stage, def in EventsConfig.stages do
		if CompanionMath.isClaimed(companion, stage) then
			total *= def.speedMult
		end
	end
	return total
end

-- Skala model Bud menurut stage.
function CompanionMath.scaleFor(stage: number): number
	local scales = { 1.0, 1.2, 1.5, 1.8 }
	return scales[CompanionMath.clampStage(stage)]
end

return CompanionMath
