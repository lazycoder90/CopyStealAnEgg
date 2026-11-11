--!strict
-- Matematika Pet Index (docs/PLAN.md §4.18, docs/ECONOMY.md rekomendasi #2). Murni, Lune-testable.
--
-- Reward speed per spesies (slot 1..8 pada zona z, recSpeed = Zones.recSpeed):
--   speed = round(speedRewardBase + (slot - 1) + recSpeed * 0.0005 * slot)
-- Penyimpangan dari "max(5, recSpeed * 0.0005 * slot)": suku dasar 5 + (slot - 1) ditambahkan (bukan max)
-- agar zona awal (recSpeed 0 / kecil) tetap naik per slot dan tiap zona selalu >= zona sebelumnya pada
-- slot yang sama. Zona akhir praktis sama dengan rumus dokumen (suku recSpeed mendominasi).

local CollectionConfig = require("../Config/CollectionConfig")
local Creatures = require("../Config/Creatures")
local Zones = require("../Config/Zones")

local IndexMath = {}

type Set = { [string]: boolean }

function IndexMath.totalSpecies(): number
	return #Creatures.list
end

function IndexMath.cashReward(speciesId: string): number
	return Creatures.get(speciesId).baseIncome * CollectionConfig.index.cashRewardMult
end

function IndexMath.speedReward(zone: number, slot: number): number
	local cfg = CollectionConfig.index
	local rec = Zones.get(zone).recSpeed
	local raw = cfg.speedRewardBase + (slot - 1) + rec * cfg.speedRewardFactor * slot
	return math.floor(raw + 0.5)
end

-- Mengembalikan cash, speed untuk satu spesies.
function IndexMath.rewards(speciesId: string): (number, number)
	local c = Creatures.get(speciesId)
	return IndexMath.cashReward(speciesId), IndexMath.speedReward(c.zone, c.slot)
end

function IndexMath.foundCount(found: Set): number
	local n = 0
	for _, c in Creatures.list do
		if found[c.id] then
			n += 1
		end
	end
	return n
end

-- Mengembalikan ditemukan, total (8) untuk satu zona.
function IndexMath.zoneProgress(found: Set, zone: number): (number, number)
	local n = 0
	local list = Creatures.byZone[zone]
	for _, c in list do
		if found[c.id] then
			n += 1
		end
	end
	return n, #list
end

function IndexMath.isZoneComplete(found: Set, zone: number): boolean
	local n, total = IndexMath.zoneProgress(found, zone)
	return n == total
end

-- Daftar zona yang lengkap (urut naik).
function IndexMath.completedZones(found: Set): { number }
	local out = {}
	for zone = 1, Zones.count do
		if IndexMath.isZoneComplete(found, zone) then
			table.insert(out, zone)
		end
	end
	return out
end

-- Spesies yang sudah ditemukan tetapi belum di-claim (urut Creatures.list).
function IndexMath.unclaimedList(found: Set, claimed: Set): { string }
	local out = {}
	for _, c in Creatures.list do
		if found[c.id] and not claimed[c.id] then
			table.insert(out, c.id)
		end
	end
	return out
end

function IndexMath.unclaimedCount(found: Set, claimed: Set): number
	return #IndexMath.unclaimedList(found, claimed)
end

-- Total reward untuk daftar spesies. Mengembalikan cash, speed.
function IndexMath.totalRewards(list: { string }): (number, number)
	local cash, speed = 0, 0
	for _, id in list do
		local c, s = IndexMath.rewards(id)
		cash += c
		speed += s
	end
	return cash, speed
end

-- Bonus income aditif dari jumlah zona lengkap (0.02 per zona).
function IndexMath.zoneBonus(zoneCount: number): number
	return zoneCount * CollectionConfig.index.zoneBonusIncome
end

return IndexMath
