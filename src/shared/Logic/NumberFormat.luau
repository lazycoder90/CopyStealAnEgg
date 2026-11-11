--!strict
-- Format angka besar: 1.5K, 12.3M, 1.5Qa, dst. Murni (tanpa API Roblox) supaya bisa dites dengan Lune.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local MAX_TIER = #SUFFIXES - 1

local NumberFormat = {}

local function sig3(scaled: number): number
	if scaled < 10 then
		return math.floor(scaled * 100 + 0.5) / 100
	elseif scaled < 100 then
		return math.floor(scaled * 10 + 0.5) / 10
	end
	return math.floor(scaled + 0.5)
end

local function trim(s: string): string
	if string.find(s, ".", 1, true) then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function NumberFormat.fmt(n: number): string
	if n ~= n then
		return "0"
	end
	if n < 0 then
		return "-" .. NumberFormat.fmt(-n)
	end
	if n < 1000 then
		return tostring(math.floor(n))
	end

	local tier = math.floor(math.log10(n) / 3)
	-- koreksi galat floating point pada log10
	while tier < MAX_TIER and n >= 10 ^ ((tier + 1) * 3) do
		tier += 1
	end
	while tier > 0 and n < 10 ^ (tier * 3) do
		tier -= 1
	end
	tier = math.min(tier, MAX_TIER)

	local rounded = sig3(n / 10 ^ (tier * 3))
	if rounded >= 1000 and tier < MAX_TIER then
		tier += 1
		rounded = 1
	end
	return trim(string.format("%.2f", rounded)) .. SUFFIXES[tier + 1]
end

local function withCommas(n: number): string
	local reversed = string.reverse(tostring(math.floor(n)))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1,")
	local out = string.reverse(grouped)
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return out
end

function NumberFormat.fmtMoney(n: number): string
	if n < 1e6 then
		return "$" .. withCommas(math.max(n, 0))
	end
	return "$" .. NumberFormat.fmt(n)
end

function NumberFormat.fmtRate(n: number): string
	return "$" .. NumberFormat.fmt(n) .. "/s"
end

function NumberFormat.fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end

return NumberFormat
