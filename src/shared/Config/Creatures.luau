--!strict
-- 96 makhluk (12 zona x 8 slot), dihitung saat require dari Zones + Rarities (docs/PLAN.md §1.5, §3.3).
-- Tidak ada tabel statis: ubah Zones/Rarities dan semuanya ikut berubah.

local Rarities = require("./Rarities")
local Zones = require("./Zones")

export type Creature = {
	id: string,
	name: string,
	zone: number,
	slot: number,
	rarity: number,
	baseKg: number,
	baseIncome: number,
}

local Creatures = {}

Creatures.baseKgBySlot = { 1.2, 2.5, 6, 14, 30, 90, 220, 520 }

-- "Moss Pup" -> "moss_pup"
function Creatures.idFromName(name: string): string
	local s = string.lower(name)
	s = string.gsub(s, "[^%w]+", "_")
	s = string.gsub(s, "^_+", "")
	s = string.gsub(s, "_+$", "")
	return s
end

local list: { Creature } = {}
local byId: { [string]: Creature } = {}
local byZone: { [number]: { Creature } } = {}

for _, zone in Zones.list do
	local zoneList: { Creature } = {}
	byZone[zone.index] = zoneList
	for slot = 1, Zones.slotsPerZone do
		local rarity = Zones.slotRarity(zone.index, slot)
		local slotVar = 1
		if slot > 1 and rarity == Zones.slotRarity(zone.index, slot - 1) then
			slotVar = 1.5
		end
		local name = zone.creatureNames[slot]
		local creature: Creature = {
			id = Creatures.idFromName(name),
			name = name,
			zone = zone.index,
			slot = slot,
			rarity = rarity,
			baseKg = Creatures.baseKgBySlot[slot],
			baseIncome = zone.baseIncome * Rarities.get(rarity).incomeMult * slotVar,
		}
		assert(byId[creature.id] == nil, "id makhluk ganda: " .. creature.id)
		byId[creature.id] = creature
		table.insert(list, creature)
		table.insert(zoneList, creature)
	end
end

Creatures.list = list
Creatures.byId = byId
Creatures.byZone = byZone

function Creatures.get(id: string): Creature
	local c = byId[id]
	assert(c, "makhluk tidak ada: " .. tostring(id))
	return c
end

return Creatures
