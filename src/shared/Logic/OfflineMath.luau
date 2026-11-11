--!strict
-- Hitungan penghasilan offline yang murni (tanpa API Roblox). Rumus uang ada di Formulas.offlineEarned.

local EconomyConfig = require("../Config/EconomyConfig")

local OfflineMath = {}

-- Batas detik offline: 24 jam (+12 jam di pen level 8+), dikali pengali tambahan (mis. VIP x2).
function OfflineMath.capSeconds(penLevel: number, extraMult: number?): number
	local cfg = EconomyConfig.offline
	local hours = cfg.capHours
	if penLevel >= cfg.penBonusLevel then
		hours += cfg.penBonusHours
	end
	return hours * 3600 * (extraMult or 1)
end

-- Selisih waktu yang dihitung: dijepit ke [0, cap]; lastOnline <= 0 (profil baru) berarti 0.
function OfflineMath.elapsed(now: number, lastOnline: number, cap: number): number
	if lastOnline ~= lastOnline or lastOnline <= 0 or now ~= now then
		return 0
	end
	return math.clamp(now - lastOnline, 0, cap)
end

-- Kemajuan telur saat offline (laju x1, tanpa malam/boost).
function OfflineMath.advanceEgg(progress: number, growTotal: number, elapsed: number): number
	return math.min(growTotal, progress + math.max(elapsed, 0))
end

-- Banner tampil hanya jika ada uang dan pemain pergi cukup lama.
function OfflineMath.shouldShowBanner(earned: number, elapsed: number): boolean
	return earned > 0 and elapsed >= EconomyConfig.offline.minBannerSeconds
end

return OfflineMath
