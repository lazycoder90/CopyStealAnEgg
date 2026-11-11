local P = require("../../src/shared/Config/Progression")
local Creatures = require("../../src/shared/Config/Creatures")
local Mutations = require("../../src/shared/Config/Mutations")

local function finite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

return function(t)
	t.eq(P.maxPenLevel, 11, "maxPenLevel")
	local prev = -1
	local increasing = true
	for lv = 1, P.maxPenLevel do
		local pen = P.pen[lv]
		t.truthy(
			finite(pen.price) and finite(pen.eggSlots) and finite(pen.visiblePets),
			"pen finite " .. lv
		)
		if pen.price <= prev then
			increasing = false
		end
		prev = pen.price
	end
	t.truthy(increasing, "harga pen naik ketat")
	t.eq(P.pen[11].visiblePets, 14, "pen 11 visible 14")

	local prevPrice = 0
	local slotsInc = true
	for slot = P.startEquipSlots + 1, P.maxEquipSlots do
		local price = P.equipSlotPrices[slot]
		t.truthy(finite(price), "equip finite " .. slot)
		if price <= prevPrice then
			slotsInc = false
		end
		prevPrice = price
	end
	t.truthy(slotsInc, "harga slot equip naik")
	t.eq(P.startEquipSlots, 3, "startEquipSlots")
	t.eq(P.maxEquipSlots, 14, "maxEquipSlots")

	t.eq(P.plotExpansion.price, 1000, "plot $1K")
	t.eq(P.wheel.maxLevel, 40, "wheel max")
	t.eq(P.eggSlotsFor(1, 0), 4, "slot telur L1")
	t.eq(P.eggSlotsFor(1, 1), 5, "slot telur L1 + ekspansi")
	t.eq(P.eggSlotsFor(11, 1), 15, "slot telur L11 + ekspansi")
	t.eq(P.visiblePetsFor(5), 7, "visible L5")

	t.eq(#P.trails, 11, "11 trail")
	local ids, prevMult, prevCash = {}, 0, 0
	local ordered = true
	for _, tr in P.trails do
		t.truthy(not ids[tr.id] and string.match(tr.id, "^[a-z_]+$") ~= nil, "trail id " .. tr.id)
		ids[tr.id] = true
		t.truthy(
			finite(tr.mult) and finite(tr.cashPrice) and finite(tr.robuxPrice),
			"trail finite " .. tr.id
		)
		if tr.mult <= prevMult or tr.cashPrice <= prevCash then
			ordered = false
		end
		prevMult, prevCash = tr.mult, tr.cashPrice
	end
	t.truthy(ordered, "trail terurut")
	t.eq(P.trails[11].mult, 20, "Prismatic Crown x20")

	-- Semua angka config hingga
	for _, c in Creatures.list do
		t.truthy(finite(c.baseIncome) and finite(c.baseKg), "finite " .. c.id)
	end
	for _, m in Mutations.list do
		t.truthy(finite(m.mult), "mut finite")
	end
end
