local Creatures = require("../../src/shared/Config/Creatures")
local Mutations = require("../../src/shared/Config/Mutations")
local Zones = require("../../src/shared/Config/Zones")

return function(t)
	t.eq(#Creatures.list, 96, "96 makhluk")
	local ids, unique = {}, true
	for _, c in Creatures.list do
		if ids[c.id] then
			unique = false
		end
		ids[c.id] = true
		t.truthy(Creatures.byId[c.id] == c, "byId " .. c.id)
		t.truthy(math.abs(c.baseIncome) < math.huge and c.baseIncome > 0, "income finite " .. c.id)
		t.truthy(c.baseKg > 0 and c.rarity >= 1 and c.rarity <= 10, "kg/rarity " .. c.id)
	end
	t.truthy(unique, "id unik")
	for z = 1, Zones.count do
		t.eq(#Creatures.byZone[z], 8, "zona " .. z .. " punya 8")
		for slot, c in Creatures.byZone[z] do
			t.eq(c.slot, slot, "slot urut")
			t.eq(c.zone, z, "zona benar")
		end
	end
	t.eq(Creatures.idFromName("Moss Pup"), "moss_pup", "idFromName")
	t.eq(Creatures.idFromName("  Hello--World! "), "hello_world", "idFromName trim/collapse")
	t.eq(Creatures.get("pebble_chick").baseIncome, 3, "Pebble Chick 3")
	t.eq(Creatures.get("moss_pup").baseIncome, 4.5, "Moss Pup 4.5")
	t.eq(Creatures.get("pebble_chick").baseKg, 1.2, "baseKg slot 1")
	t.eq(Creatures.byZone[1][8].baseKg, 520, "baseKg slot 8")
	t.eq(Creatures.list[1].id, "pebble_chick", "urutan zona lalu slot")
	t.eq(Creatures.list[9].zone, 2, "urutan zona 2")
	t.eq(pcall(Creatures.get, "nope"), false, "get tak dikenal -> assert")

	-- Mutations
	t.eq(Mutations.maxPerItem, 3, "maxPerItem")
	t.eq(#Mutations.order, 6, "order")
	for _, name in Mutations.order do
		local m = Mutations.list[name]
		t.truthy(m ~= nil and math.abs(m.mult) < math.huge, "mult finite " .. name)
	end
	t.eq(Mutations.moonlitChancePerNight, 0.04, "moonlit")
end
