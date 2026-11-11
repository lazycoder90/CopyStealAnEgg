--!strict
-- Aturan PvP murni (tanpa Instance/Vector3) supaya bisa dites di Lune.
-- Dipakai DefenseService (server) dan DefenseController/PanController (klien, hanya konstanta).

local PvpRules = {}

PvpRules.panToolName = "Frying Pan"
PvpRules.panCooldown = 1.2 -- detik (waktu nyata)
PvpRules.panRange = 9 -- stud
PvpRules.panHalfAngle = 70 -- derajat dari LookVector
PvpRules.panMaxHeightDiff = 7 -- selisih tinggi maksimum (stud)
PvpRules.panStun = 0.5 -- detik WalkSpeed = 0
PvpRules.panKnockForce = 45
PvpRules.panKnockUp = 25
PvpRules.panBonkImmunity = 1.5 -- detik kebal pickup setelah kena Pan

PvpRules.trapMinCost = 10000
PvpRules.trapIncomeSeconds = 120
PvpRules.trapLifetime = 300 -- detik waktu nyata
PvpRules.trapTriggerRadius = 4
PvpRules.trapStunSeconds = 7
PvpRules.trapMaxPlotDistance = 30
PvpRules.trapMaxOwnerDistance = 20
PvpRules.trapSize = 7

PvpRules.shieldBaseDuration = 60
PvpRules.shieldPenBonus = 15
PvpRules.shieldPenLevel = 4
PvpRules.shieldCooldown = 600
PvpRules.shieldPushInterval = 0.2
PvpRules.trapSecondPenLevel = 6

-- Apakah titik (dx, dz) relatif penyerang berada dalam kerucut ayun? (bidang horizontal)
-- lookX/lookZ = arah pandang penyerang (tidak harus ternormalisasi). Jarak 0 dianggap kena.
function PvpRules.inSwingCone(
	dx: number,
	dz: number,
	lookX: number,
	lookZ: number,
	range: number,
	halfAngleDeg: number
): boolean
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > range then
		return false
	end
	if dist < 1e-6 then
		return true
	end
	local lookLen = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookLen < 1e-6 then
		return false
	end
	local cosAngle = (dx * lookX + dz * lookZ) / (dist * lookLen)
	local limit = math.cos(math.rad(halfAngleDeg))
	return cosAngle >= limit - 1e-9
end

-- Cooldown: true bila sudah boleh beraksi. lastAt nil = belum pernah.
function PvpRules.cooldownReady(lastAt: number?, now: number, cooldown: number): boolean
	if lastAt == nil then
		return true
	end
	return now - lastAt >= cooldown - 1e-9
end

-- Harga Sticky Yolk Trap: 2 menit penghasilan pemilik, minimal 10.000.
function PvpRules.trapCost(incomePerSec: number?): number
	local income = incomePerSec or 0
	if income ~= income or income < 0 then
		income = 0
	end
	return math.max(PvpRules.trapMinCost, income * PvpRules.trapIncomeSeconds)
end

function PvpRules.maxTraps(penLevel: number?): number
	if (penLevel or 1) >= PvpRules.trapSecondPenLevel then
		return 2
	end
	return 1
end

function PvpRules.shieldDuration(penLevel: number?): number
	local seconds = PvpRules.shieldBaseDuration
	if (penLevel or 1) >= PvpRules.shieldPenLevel then
		seconds += PvpRules.shieldPenBonus
	end
	return seconds
end

-- Titik (x, z) berada di dalam lingkaran (pusat cx, cz, jari-jari r)?
function PvpRules.inCircle(x: number, z: number, cx: number, cz: number, r: number): boolean
	local dx, dz = x - cx, z - cz
	return dx * dx + dz * dz <= r * r
end

-- Titik lokal (x, z) berada di dalam persegi plot (setengah sisi = half)?
function PvpRules.insideSquare(x: number, z: number, half: number): boolean
	return math.abs(x) <= half and math.abs(z) <= half
end

-- Dorong titik lokal di dalam persegi (setengah sisi half) ke luar lewat sisi terdekat,
-- berhenti `margin` stud di luar pagar. Titik di luar dikembalikan apa adanya.
function PvpRules.pushOutside(x: number, z: number, half: number, margin: number): (number, number)
	if not PvpRules.insideSquare(x, z, half) then
		return x, z
	end
	local toPosX, toNegX = half - x, x + half
	local toPosZ, toNegZ = half - z, z + half
	local best = math.min(toPosX, toNegX, toPosZ, toNegZ)
	local out = half + margin
	if best == toPosX then
		return out, z
	elseif best == toNegX then
		return -out, z
	elseif best == toPosZ then
		return x, out
	end
	return x, -out
end

return PvpRules
