--!strict
-- Tata letak dunia (stud). Sumbu lane = +Z. Semua koordinat world kecuali dicatat lain.
-- Murni angka (bukan Vector3) supaya bisa dites di Lune.

local Layout = {}

Layout.hubZMin = -320
Layout.hubZMax = 150 -- lantai hub berlanjut sampai awal lane (tanpa celah); Hearth Line di z = hearthLineZ
Layout.hubHalfWidth = 420

Layout.hearthLineZ = 120
Layout.laneStartZ = 150
Layout.zoneLength = 300
Layout.laneWidth = 120 -- lebar lane (X dari -60 sampai 60)
Layout.wallHeight = 30

-- Spawn pad PvP-free di hub.
Layout.spawnPad = { x = 0, z = 70, radius = 26 }

-- 8 Coop: 2 baris x 4 kolom.
Layout.plotCount = 8
Layout.plotSize = 80 -- sisi persegi
Layout.plotColumns = 4
Layout.plotSpacingX = 130
Layout.plotRowZ = { -20, -150 }

-- Posisi lokal (relatif pusat lantai plot) tempat pemain muncul, dan area yang tidak boleh dipakai telur.
Layout.plotSpawnLocal = { x = 0, z = 24 }
Layout.plotReserved = {
	{ x = 0, z = 24, r = 8 }, -- titik spawn
	{ x = -26, z = -26, r = 14 }, -- Sprint Wheel (Fase 2)
}
Layout.plotGateWidth = 16 -- celah pagar di sisi lane (+Z)

function Layout.plotCenter(index: number): (number, number)
	local col = (index - 1) % Layout.plotColumns
	local row = (index - 1) // Layout.plotColumns
	local x = (col - (Layout.plotColumns - 1) / 2) * Layout.plotSpacingX
	return x, Layout.plotRowZ[row + 1]
end

function Layout.zoneZStart(zoneIndex: number): number
	return Layout.laneStartZ + (zoneIndex - 1) * Layout.zoneLength
end

function Layout.zoneZEnd(zoneIndex: number): number
	return Layout.zoneZStart(zoneIndex) + Layout.zoneLength
end

-- Zona (1..12) tempat koordinat Z berada, atau nil jika di luar lane.
function Layout.zoneAtZ(z: number): number?
	if z < Layout.laneStartZ then
		return nil
	end
	local index = (z - Layout.laneStartZ) // Layout.zoneLength + 1
	if index > 12 then
		return nil
	end
	return index
end

return Layout
