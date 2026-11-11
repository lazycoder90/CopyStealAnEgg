--!strict
-- Hitungan monetisasi yang murni (tanpa API Roblox, bisa dites di Lune).

local MonetizationConfig = require("../Config/MonetizationConfig")

local MonetizationMath = {}

-- Nomor tier Skip Growth menurut sisa detik (batas atas eksklusif: tepat 300 detik = tier 2).
function MonetizationMath.skipTier(remainingSeconds: number): number
	local tiers = MonetizationConfig.skipTiers
	for i, tier in tiers do
		if remainingSeconds < tier.maxSeconds then
			return i
		end
	end
	return #tiers
end

-- Uang paket cash = income/detik x menit x 60, minimal MonetizationConfig.minCash.
function MonetizationMath.cashPackAmount(incomePerSec: number, minutes: number): number
	local amount = incomePerSec * minutes * 60
	if amount ~= amount then
		amount = 0
	end
	return math.max(amount, MonetizationConfig.minCash)
end

function MonetizationMath.compensationCash(incomePerSec: number): number
	return MonetizationMath.cashPackAmount(incomePerSec, MonetizationConfig.compensationMinutes)
end

-- Lebih baru = timestamp lebih besar; imbang diputuskan PurchaseId numerik (lalu teks).
local function isNewer(a: { key: string, at: number }, b: { key: string, at: number }): boolean
	if a.at ~= b.at then
		return a.at > b.at
	end
	local na, nb = tonumber(a.key), tonumber(b.key)
	if na and nb and na ~= nb then
		return na > nb
	end
	return a.key > b.key
end

-- Memangkas receipts ({[kunci string] = timestamp}) agar tersisa `keep` terbaru. Mengembalikan jumlah terhapus.
function MonetizationMath.pruneReceipts(receipts: { [string]: number }, keep: number): number
	local list = {}
	for key, at in receipts do
		table.insert(list, { key = key, at = if type(at) == "number" then at else 0 })
	end
	if #list <= keep then
		return 0
	end
	table.sort(list, isNewer)
	local removed = 0
	for i = keep + 1, #list do
		receipts[list[i].key] = nil
		removed += 1
	end
	return removed
end

-- Teks hitung mundur: "2d 03:12:44" atau "03:12:44". Selesai/negatif -> "00:00:00".
function MonetizationMath.formatCountdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days = s // 86400
	local h = (s % 86400) // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if days > 0 then
		return string.format("%dd %02d:%02d:%02d", days, h, m, sec)
	end
	return string.format("%02d:%02d:%02d", h, m, sec)
end

return MonetizationMath
