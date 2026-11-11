--!strict
-- Matematika murni Dash Derby (Lune-testable): posisi gerbang, persilangan segmen-vs-bidang gerbang,
-- progres checkpoint berurutan, peringkat, rumus trophy, dan bobot zona.

local Layout = require("../Config/Layout")
local RaceConfig = require("../Config/RaceConfig")
local RNG = require("./RNG")
local Zones = require("../Config/Zones")

local RaceMath = {}

local FINISH_INDEX = RaceConfig.checkpointCount + 1
RaceMath.finishIndex = FINISH_INDEX
RaceMath.gateCount = FINISH_INDEX + 1 -- gerbang 0..finish

-- Z gerbang index 0..finish: start = awal zona + inset, finish = akhir zona - inset, sisanya merata.
function RaceMath.gateZ(zone: number, index: number): number
	local startZ = Layout.zoneZStart(zone) + RaceConfig.gateInset
	local finishZ = Layout.zoneZEnd(zone) - RaceConfig.gateInset
	return startZ + (finishZ - startZ) * index / FINISH_INDEX
end

export type Crossing = { index: number, t: number } -- t = fraksi segmen (0..1) saat melewati bidang

-- Apakah segmen prev->curr menembus bidang z = gateZ ke arah +Z dengan |x| <= halfWidth?
-- Mengembalikan fraksi t (0..1) atau nil.
function RaceMath.crossing(
	prevX: number,
	prevZ: number,
	currX: number,
	currZ: number,
	gateZ: number,
	halfWidth: number
): number?
	if not (prevZ < gateZ and currZ >= gateZ) then
		return nil -- hanya arah +Z; mulai tepat di bidang tidak dihitung
	end
	local t = (gateZ - prevZ) / (currZ - prevZ)
	local x = prevX + t * (currX - prevX)
	if math.abs(x) > halfWidth then
		return nil
	end
	return t
end

-- Semua gerbang yang ditembus segmen, urut menurut Z naik (= urutan index).
function RaceMath.crossings(
	zone: number,
	prevX: number,
	prevZ: number,
	currX: number,
	currZ: number,
	halfWidth: number
): { Crossing }
	local out = {}
	for index = 0, FINISH_INDEX do
		local t =
			RaceMath.crossing(prevX, prevZ, currX, currZ, RaceMath.gateZ(zone, index), halfWidth)
		if t then
			table.insert(out, { index = index, t = t })
		end
	end
	return out
end

-- Progres percobaan. last = gerbang terakhir yang sah (-1 = belum mulai).
-- Menembus gerbang 0 selalu (re)start; gerbang k hanya sah bila last == k-1; selain itu diabaikan.
-- Mengembalikan last baru dan daftar kejadian { {kind = "start"|"checkpoint"|"finish", index, t} }.
function RaceMath.advance(last: number, crossed: { Crossing }): (number, { { [string]: any } })
	local events = {}
	for _, c in crossed do
		if c.index == 0 then
			last = 0
			table.insert(events, { kind = "start", index = 0, t = c.t })
		elseif c.index == last + 1 then
			last = c.index
			local kind = if c.index == FINISH_INDEX then "finish" else "checkpoint"
			table.insert(events, { kind = kind, index = c.index, t = c.t })
			if kind == "finish" then
				last = -1 -- percobaan selesai; harus melewati start lagi
			end
		end
	end
	return last, events
end

-- Urutkan peserta {userId, time} menurut waktu naik (seri: userId kecil dulu).
function RaceMath.rank(
	entries: { { userId: number, time: number } }
): { { userId: number, time: number } }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.userId < b.userId
	end)
	return list
end

-- Apakah waktu `best` memecahkan rekor lama (nil = belum ada rekor)?
function RaceMath.beatsRecord(best: number, old: number?): boolean
	return old == nil or best < old
end

-- Trophy = 50 x zona x pengali peringkat (1/2/3 = 4/3/2) + 25 x zona bila rekor pribadi.
function RaceMath.trophies(zone: number, rank: number, beatRecord: boolean): number
	local base = RaceConfig.baseTrophiesPerZone * zone
	local amount = base * (RaceConfig.rankMultipliers[rank] or 1)
	if beatRecord then
		amount += RaceConfig.recordBonusPerZone * zone
	end
	return amount
end

-- Zona tertinggi yang layak: recSpeed <= headroom x speed tertinggi; minimal minZone, maksimal maxZone.
function RaceMath.maxZoneFor(topSpeed: number): number
	local best = RaceConfig.minZone
	local limit = math.min(RaceConfig.maxZone, Zones.count)
	for zone = 1, limit do
		if Zones.get(zone).recSpeed <= topSpeed * RaceConfig.speedHeadroom then
			best = math.max(best, zone)
		end
	end
	return best
end

-- Bobot zona 1..n: condong ke zona tinggi (bobot = zona).
function RaceMath.zoneWeights(n: number): { number }
	local weights = {}
	for zone = 1, n do
		weights[zone] = zone
	end
	return weights
end

function RaceMath.pickZone(n: number, rng: RNG.RNG): number
	return rng:weighted(RaceMath.zoneWeights(n))
end

-- Angka dengan pemisah ribuan: 2025 -> "2,025".
function RaceMath.commas(n: number): string
	local out = string.format("%d", math.floor(n + 0.5))
	while true do
		local replaced, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if count == 0 then
			break
		end
	end
	return out
end

-- Waktu balapan "mm:ss.cc" (dibulatkan ke bawah per sentidetik).
function RaceMath.formatTime(seconds: number): string
	local total = math.max(0, math.floor(seconds * 100 + 1e-6))
	local cs = total % 100
	local secs = (total // 100) % 60
	local mins = total // 6000
	return string.format("%02d:%02d.%02d", mins, secs, cs)
end

return RaceMath
