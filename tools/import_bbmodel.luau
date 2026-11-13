--!nonstrict
-- Mengubah model Blockbench (.bbmodel) menjadi modul data kubus untuk ModelFactory.
-- Jalankan: lune run tools/import_bbmodel art/halo_jelly/Jellyfish.bbmodel src/shared/Models/HaloJellyData.luau
-- Warna dipilih dari kuadran UV 8x8 pada tekstur 64x64 (kuadran = uv[1] // 8); nama berawalan "G_" = glow.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local inPath, outPath = process.args[1], process.args[2]
assert(inPath and outPath, "pemakaian: import_bbmodel <masuk.bbmodel> <keluar.luau>")

local model = serde.decode("json", fs.readFile(inPath))
local function r(n: number): string
	return string.format("%.4g", n)
end

local lines = {
	"--!strict",
	"-- DIHASILKAN oleh tools/import_bbmodel.luau dari " .. inPath .. ". Jangan diedit manual.",
	"-- Tiap kubus: { x0, y0, z0, x1, y1, z1, ox, oy, oz, rx, ry, rz, warna, glow } (pixel Blockbench, derajat).",
	"-- warna: 1 putih, 2 putih-bayangan, 3 emas, 4 emas-terang.",
	"return {",
	"\tpalette = {",
	"\t\t{ 236, 240, 252 },",
	"\t\t{ 214, 228, 246 },",
	"\t\t{ 255, 214, 90 },",
	"\t\t{ 255, 250, 205 },",
	"\t},",
	"\tcubes = {",
}
local count, glow = 0, 0
for _, e in model.elements do
	if e.type == "cube" then
		local face = e.faces.north or e.faces[next(e.faces)]
		local color = math.floor(face.uv[1] / 8) + 1
		assert(color >= 1 and color <= 4, "warna di luar palet: " .. e.name)
		local rot = e.rotation or { 0, 0, 0 }
		local origin = e.origin or { 0, 0, 0 }
		local isGlow = string.sub(e.name, 1, 2) == "G_"
		count += 1
		if isGlow then
			glow += 1
		end
		table.insert(
			lines,
			string.format(
				"\t\t{ %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %d, %s },",
				r(e.from[1]),
				r(e.from[2]),
				r(e.from[3]),
				r(e.to[1]),
				r(e.to[2]),
				r(e.to[3]),
				r(origin[1]),
				r(origin[2]),
				r(origin[3]),
				r(rot[1]),
				r(rot[2]),
				r(rot[3]),
				color,
				tostring(isGlow)
			)
		)
	end
end
table.insert(lines, "\t},")
table.insert(lines, "}")
fs.writeFile(outPath, table.concat(lines, "\n") .. "\n")
print(`{count} kubus ({glow} glow) -> {outPath}`)
