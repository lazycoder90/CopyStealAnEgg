--!strict
-- Matematika murni polish: pencampuran warna, parameter atmosfer per zona, skala UI dari viewport.
-- Warna = tabel { r, g, b } 0..255 (tanpa Color3 agar bisa dites di Lune).

local PolishConfig = require("../Config/PolishConfig")
local Zones = require("../Config/Zones")

local AtmosphereMath = {}

export type Rgb = { number }
export type Params = {
	haze: Rgb,
	hazeDensity: number,
	hazeOffset: number,
	glare: number,
	tint: Rgb,
	brightness: number,
	contrast: number,
	saturation: number,
	bloomIntensity: number,
	bloomSize: number,
	bloomThreshold: number,
	sunRays: number,
}

local function clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

-- Campur dua warna; t dijepit ke 0..1 (t=0 -> a, t=1 -> b).
function AtmosphereMath.blend(a: Rgb, b: Rgb, t: number): Rgb
	local k = clamp(t, 0, 1)
	return {
		a[1] + (b[1] - a[1]) * k,
		a[2] + (b[2] - a[2]) * k,
		a[3] + (b[3] - a[3]) * k,
	}
end

-- Kecerahan persepsi 0..1.
function AtmosphereMath.luminance(c: Rgb): number
	return (0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]) / 255
end

local WHITE = { 255, 255, 255 }

local function copyParams(p: Params): Params
	return {
		haze = { p.haze[1], p.haze[2], p.haze[3] },
		hazeDensity = p.hazeDensity,
		hazeOffset = p.hazeOffset,
		glare = p.glare,
		tint = { p.tint[1], p.tint[2], p.tint[3] },
		brightness = p.brightness,
		contrast = p.contrast,
		saturation = p.saturation,
		bloomIntensity = p.bloomIntensity,
		bloomSize = p.bloomSize,
		bloomThreshold = p.bloomThreshold,
		sunRays = p.sunRays,
	}
end

function AtmosphereMath.hub(): Params
	return copyParams(PolishConfig.atmosphere.hub :: any)
end

-- Parameter atmosfer untuk zona (1..12). nil / di luar jangkauan = hub.
function AtmosphereMath.forZone(zoneIndex: number?): Params
	local zone = zoneIndex and Zones.list[zoneIndex]
	if not zone then
		return AtmosphereMath.hub()
	end
	local hub = PolishConfig.atmosphere.hub :: any
	local out = copyParams(hub)
	local floorRgb, wallRgb = zone.floorRgb, zone.wallRgb
	local dark = 1 - AtmosphereMath.luminance(floorRgb) -- zona gelap = kabut lebih pekat
	-- Warna kabut: lantai dicampur sedikit dinding, lalu dicerahkan sesuai kegelapan zona.
	local base = AtmosphereMath.blend(floorRgb, wallRgb, 0.35)
	out.haze = AtmosphereMath.blend(base, WHITE, 0.3 * (1 - dark))
	out.hazeDensity = 0.25 + 0.15 * clamp(dark, 0, 1)
	out.hazeOffset = 0.1 + 0.15 * dark
	out.glare = 0
	out.bloomIntensity = clamp(0.18 + 0.2 * clamp(1 - dark, 0, 1), 0.1, 0.5)
	out.bloomThreshold = 1.1 - 0.25 * dark
	out.sunRays = 0.06 * (1 - dark)

	local grade = (PolishConfig.atmosphere.zoneGrade :: any)[zoneIndex]
	if grade then
		out.tint = { grade[1][1], grade[1][2], grade[1][3] }
		out.saturation = grade[2]
		out.contrast = grade[3]
		out.brightness = grade[4]
	else
		out.tint = AtmosphereMath.blend(WHITE, floorRgb, 0.15)
		out.saturation = 0.1
		out.contrast = 0.06
		out.brightness = 0
	end
	return out
end

-- Skala UI dari ukuran viewport (piksel). Dasar: tinggi 1080 = 1.0.
-- touchOnly: perangkat sentuh tanpa keyboard (x1.1, batas bawah 0.75 supaya tombol >= 44 px).
function AtmosphereMath.uiScaleForViewport(
	width: number,
	height: number,
	touchOnly: boolean?
): number
	local cfg = PolishConfig.scale
	local w = math.max(1, width)
	local h = math.max(1, height)
	local raw = math.min(h / cfg.baseHeight, w / cfg.baseWidth)
	local scale = clamp(raw, cfg.min, cfg.max)
	if touchOnly then
		scale = math.max(cfg.touchMin, scale * cfg.touchMultiplier)
	end
	return scale
end

return AtmosphereMath
