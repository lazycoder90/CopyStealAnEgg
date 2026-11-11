--!strict
-- Posisi sarang per zona (deterministik, murni). Dipakai EggSpawnService dan dites di Lune.

local Layout = require("../Config/Layout")
local Eggs = require("../Config/Eggs")
local RNG = require("./RNG")

export type Nest = { id: string, zone: number, x: number, z: number, grand: boolean }

local NestLayout = {}

NestLayout.minSpacing = 22
NestLayout.xRange = 44 -- sarang kecil di X dalam [-44, 44]
NestLayout.grandClearance = 35
NestLayout.grandEndOffset = 40 -- sarang besar berjarak segini dari ujung zona
NestLayout.smallStartMargin = 25
NestLayout.smallEndMargin = 75

function NestLayout.grandPosition(zoneIndex: number): (number, number)
	return 0, Layout.zoneZEnd(zoneIndex) - NestLayout.grandEndOffset
end

function NestLayout.forZone(zoneIndex: number): { Nest }
	local rng = RNG.new(1000 + zoneIndex)
	local zStart = Layout.zoneZStart(zoneIndex)
	local zEnd = Layout.zoneZEnd(zoneIndex)
	local list: { Nest } = {}

	for g = 1, Eggs.grandNestsPerZone do
		local gx, gz = NestLayout.grandPosition(zoneIndex)
		table.insert(
			list,
			{ id = `z{zoneIndex}_g{g}`, zone = zoneIndex, x = gx, z = gz, grand = true }
		)
	end

	local placed = 0
	local attempts = 0
	while placed < Eggs.smallNestsPerZone and attempts < 2000 do
		attempts += 1
		local x = rng:range(-NestLayout.xRange, NestLayout.xRange)
		local z = rng:range(zStart + NestLayout.smallStartMargin, zEnd - NestLayout.smallEndMargin)
		local ok = true
		for _, other in list do
			local limit = if other.grand then NestLayout.grandClearance else NestLayout.minSpacing
			local dx, dz = x - other.x, z - other.z
			if dx * dx + dz * dz < limit * limit then
				ok = false
				break
			end
		end
		if ok then
			placed += 1
			table.insert(
				list,
				{ id = `z{zoneIndex}_s{placed}`, zone = zoneIndex, x = x, z = z, grand = false }
			)
		end
	end
	return list
end

return NestLayout
