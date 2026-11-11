local Layout = require("../../src/shared/Config/Layout")
local Eggs = require("../../src/shared/Config/Eggs")
local NestLayout = require("../../src/shared/Logic/NestLayout")

return function(t)
	for zone = 1, 12 do
		local nests = NestLayout.forZone(zone)
		local zStart, zEnd = Layout.zoneZStart(zone), Layout.zoneZEnd(zone)

		t.eq(#nests, Eggs.smallNestsPerZone + Eggs.grandNestsPerZone, `zona {zone}: jumlah sarang`)

		local ids, grandCount = {}, 0
		local allInside, spacingOk = true, true
		for i, n in nests do
			if ids[n.id] then
				t.truthy(false, `zona {zone}: id duplikat {n.id}`)
			end
			ids[n.id] = true
			if n.grand then
				grandCount += 1
			end
			if n.z < zStart or n.z > zEnd or math.abs(n.x) > Layout.laneWidth / 2 then
				allInside = false
			end
			for j = i + 1, #nests do
				local o = nests[j]
				local dx, dz = n.x - o.x, n.z - o.z
				local limit = if n.grand or o.grand
					then NestLayout.grandClearance
					else NestLayout.minSpacing
				if dx * dx + dz * dz < limit * limit - 1e-6 then
					spacingOk = false
				end
			end
		end
		t.eq(grandCount, Eggs.grandNestsPerZone, `zona {zone}: jumlah sarang besar`)
		t.truthy(allInside, `zona {zone}: semua sarang di dalam zona`)
		t.truthy(spacingOk, `zona {zone}: jarak antar sarang cukup`)
	end

	-- Deterministik
	local a, b = NestLayout.forZone(3), NestLayout.forZone(3)
	local same = #a == #b
	for i = 1, #a do
		if a[i].x ~= b[i].x or a[i].z ~= b[i].z then
			same = false
		end
	end
	t.truthy(same, "forZone deterministik")

	-- Layout
	t.eq(Layout.zoneAtZ(Layout.laneStartZ + 1), 1, "zoneAtZ awal")
	t.eq(Layout.zoneAtZ(Layout.zoneZEnd(12) - 1), 12, "zoneAtZ akhir")
	t.eq(Layout.zoneAtZ(Layout.laneStartZ - 1), nil, "zoneAtZ sebelum lane")
	t.eq(Layout.zoneAtZ(Layout.zoneZEnd(12) + 1), nil, "zoneAtZ setelah lane")
	-- 8 plot tidak saling tumpang tindih
	local overlap = false
	for i = 1, Layout.plotCount do
		for j = i + 1, Layout.plotCount do
			local x1, z1 = Layout.plotCenter(i)
			local x2, z2 = Layout.plotCenter(j)
			if math.abs(x1 - x2) < Layout.plotSize and math.abs(z1 - z2) < Layout.plotSize then
				overlap = true
			end
		end
	end
	t.truthy(not overlap, "plot tidak tumpang tindih")

	-- Tidak ada celah lantai antara hub dan lane, dan Hearth Line berada di dalam hub
	t.truthy(Layout.hubZMax >= Layout.laneStartZ, "lantai hub menyambung ke lane")
	t.truthy(
		Layout.hearthLineZ < Layout.hubZMax and Layout.hearthLineZ > Layout.hubZMin,
		"Hearth Line di dalam hub"
	)
end
