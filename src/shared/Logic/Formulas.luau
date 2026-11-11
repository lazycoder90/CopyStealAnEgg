--!strict
-- Rumus ekonomi/progresi (lihat docs/PLAN.md §3). Murni, tanpa API Roblox.

local Formulas = {}

local MAX_WALK_SPEED = 170
local MIN_WALK_SPEED = 16

-- Stat "Speed" (angka besar di HUD) -> WalkSpeed Humanoid.
function Formulas.walkSpeed(effectiveSpeed: number): number
	local v = MIN_WALK_SPEED + 9 * math.log10(math.max(effectiveSpeed, 0) / 10 + 1)
	return math.clamp(v, MIN_WALK_SPEED, MAX_WALK_SPEED)
end

function Formulas.effectiveSpeed(
	speedBase: number,
	trailMult: number?,
	hasDoubleSpeed: boolean?,
	hasSpeedPotion: boolean?
): number
	return speedBase
		* (trailMult or 1)
		* (if hasDoubleSpeed then 2 else 1)
		* (if hasSpeedPotion then 1.5 else 1)
end

-- Sprint Wheel: speed yang didapat per step pada level L.
function Formulas.wheelGainPerStep(level: number): number
	return math.floor(2 * 1.75 ^ (level - 1) + 0.5)
end

-- Harga naik dari level L ke L+1.
function Formulas.wheelUpgradePrice(level: number): number
	return 500 * 3 ^ (level - 1)
end

-- Penghasilan offline: "per hari offline" = 1 jam income online.
function Formulas.offlinePerDay(incomePerSec: number): number
	return incomePerSec * 3600
end

function Formulas.offlineEarned(incomePerSec: number, elapsedSec: number, capSec: number): number
	local effective = math.min(math.max(elapsedSec, 0), capSec)
	return Formulas.offlinePerDay(incomePerSec) * effective / 86400
end

function Formulas.sellEggValue(projectedIncomePerSec: number): number
	return 80 * projectedIncomePerSec
end

function Formulas.sellPetValue(petIncomePerSec: number): number
	return 100 * petIncomePerSec
end

-- Pengali berat: naik sublinear terhadap berat relatif.
function Formulas.weightMult(kg: number, baseKg: number): number
	return (kg / baseKg) ^ 0.6
end

-- Mutasi ditambahkan (bukan dikalikan): 1 + sum(m_i - 1).
function Formulas.mutationMult(mults: { number }): number
	local total = 1
	for _, m in mults do
		total += m - 1
	end
	return total
end

return Formulas
