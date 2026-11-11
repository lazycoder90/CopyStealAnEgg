--!strict
-- Matematika papan peringkat (murni): encode/decode nilai besar ke integer OrderedDataStore,
-- pengurutan baris, dan aturan tulis ulang.

local LeaderboardMath = {}

local SCALE = 1e9
local MAX_VALUE = 1e300

-- floor(log10(x+1) * 1e9). Monoton naik; x dijepit ke [0, 1e300]. Maks ~3e11 (muat integer 2^53).
function LeaderboardMath.encode(x: number): number
	if x ~= x or x <= 0 then
		return 0
	end
	return math.floor(math.log10(math.min(x, MAX_VALUE) + 1) * SCALE)
end

function LeaderboardMath.decode(v: number): number
	if v ~= v or v <= 0 then
		return 0
	end
	return 10 ^ (v / SCALE) - 1
end

-- Baris { value, userId } diurutkan menurun (seri: userId kecil dulu), maksimal limit.
function LeaderboardMath.rank(entries: { any }, limit: number): { any }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.userId < b.userId
	end)
	while #list > limit do
		table.remove(list)
	end
	return list
end

-- Tulis hanya jika nilai > 0 dan (belum pernah ditulis atau berubah >= minChange).
function LeaderboardMath.shouldWrite(last: number?, value: number, minChange: number): boolean
	if value ~= value or value <= 0 then
		return false
	end
	if last == nil or last <= 0 then
		return true
	end
	return math.abs(value - last) / last >= minChange
end

return LeaderboardMath
