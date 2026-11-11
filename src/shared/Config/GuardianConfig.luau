--!strict
-- Konfigurasi Nestwarden (docs/PLAN.md §3.2 dan §4.3). Murni, bisa dites di Lune.

local Layout = require("./Layout")

local GuardianConfig = {}

GuardianConfig.wakeDelay = 1.2 -- detik antara Alert dan Chase
GuardianConfig.wakeDelayGrand = 0.8 -- untuk telur Grand Nest
GuardianConfig.leash = 700 -- jarak maks dari rumah sebelum pulang
GuardianConfig.catchRadiusBase = 7
GuardianConfig.catchRadiusPerSpeed = 0.1 -- radius efektif = 7 + 0.1 * walkSpeed target
GuardianConfig.chaseSpeedFactor = 1.05
GuardianConfig.returnSpeedFactor = 0.6
GuardianConfig.maxChaseSeconds = 25
GuardianConfig.activeRadius = 400 -- guardian tidur hanya dikerjakan bila ada pemain sedekat ini
GuardianConfig.alertShakeRadius = 150
GuardianConfig.tutorialIgnore = true -- pemain yang masih tutorial tidak membangunkan guardian
GuardianConfig.hearthMargin = 4 -- guardian tidak pernah di bawah hearthLineZ + margin
GuardianConfig.homeOffsetFromZoneEnd = 62 -- rumah tepat di samping Grand Nest
GuardianConfig.catchStunSeconds = 1.5
GuardianConfig.catchImmunitySeconds = 2
GuardianConfig.catchGraceSeconds = 2.5
GuardianConfig.knockHorizontal = 60
GuardianConfig.knockUp = 30

-- Posisi rumah guardian zona tertentu (x, z).
function GuardianConfig.home(zoneIndex: number): (number, number)
	return 0, Layout.zoneZEnd(zoneIndex) - GuardianConfig.homeOffsetFromZoneEnd
end

function GuardianConfig.catchRadius(targetWalkSpeed: number): number
	return GuardianConfig.catchRadiusBase + GuardianConfig.catchRadiusPerSpeed * targetWalkSpeed
end

function GuardianConfig.minZ(): number
	return Layout.hearthLineZ + GuardianConfig.hearthMargin
end

return GuardianConfig
