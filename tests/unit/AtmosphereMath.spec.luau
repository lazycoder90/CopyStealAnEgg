local AtmosphereMath = require("../../src/shared/Logic/AtmosphereMath")
local PolishConfig = require("../../src/shared/Config/PolishConfig")
local Zones = require("../../src/shared/Config/Zones")

local function inRange(v, range)
	return v >= range[1] - 1e-9 and v <= range[2] + 1e-9
end

local function rgbOk(c)
	for i = 1, 3 do
		if c[i] < 0 or c[i] > 255 then
			return false
		end
	end
	return true
end

return function(t)
	-- blend
	local a, b = { 0, 100, 200 }, { 200, 100, 0 }
	local m0 = AtmosphereMath.blend(a, b, 0)
	local m1 = AtmosphereMath.blend(a, b, 1)
	t.eq(m0[1], 0, "blend t=0 r")
	t.eq(m1[1], 200, "blend t=1 r")
	t.eq(m1[3], 0, "blend t=1 b")
	t.eq(AtmosphereMath.blend(a, b, 2)[1], 200, "blend jepit atas")
	t.eq(AtmosphereMath.blend(a, b, -1)[1], 0, "blend jepit bawah")
	local again = AtmosphereMath.blend(m1, b, 1)
	t.eq(again[1], m1[1], "blend idempoten pada t=1 ke warna sama")
	local prev = -1
	for i = 0, 10 do
		local r = AtmosphereMath.blend(a, b, i / 10)[1]
		t.truthy(r >= prev, "blend monoton")
		prev = r
	end

	-- parameter 12 zona
	local bounds = PolishConfig.atmosphere.bounds
	for i = 1, #Zones.list do
		local p = AtmosphereMath.forZone(i)
		t.truthy(inRange(p.hazeDensity, bounds.density), `zona {i} density`)
		t.truthy(inRange(p.bloomIntensity, bounds.bloomIntensity), `zona {i} bloom`)
		t.truthy(inRange(p.saturation, bounds.saturation), `zona {i} saturation`)
		t.truthy(inRange(p.contrast, bounds.contrast), `zona {i} contrast`)
		t.truthy(inRange(p.brightness, bounds.brightness), `zona {i} brightness`)
		t.truthy(rgbOk(p.haze), `zona {i} haze rgb`)
		t.truthy(rgbOk(p.tint), `zona {i} tint rgb`)
	end
	local hub = AtmosphereMath.forZone(nil)
	t.eq(hub.hazeDensity, PolishConfig.atmosphere.hub.hazeDensity, "hub density")
	t.eq(AtmosphereMath.forZone(99).hazeDensity, hub.hazeDensity, "zona tak ada = hub")
	-- gloomrift lebih gelap dan pekat daripada meadow
	t.truthy(
		AtmosphereMath.forZone(12).hazeDensity > AtmosphereMath.forZone(1).hazeDensity,
		"gloomrift lebih pekat"
	)
	-- salinan hub tidak mengubah config
	local h1 = AtmosphereMath.hub()
	h1.haze[1] = 1
	t.eq(PolishConfig.atmosphere.hub.haze[1], 255, "hub mengembalikan salinan")

	-- skala viewport
	local sizes = {
		{ 320, 480 },
		{ 640, 360 },
		{ 1280, 720 },
		{ 1600, 900 },
		{ 1920, 1080 },
		{ 2560, 1440 },
		{ 3840, 2160 },
	}
	local last = 0
	for _, s in sizes do
		local scale = AtmosphereMath.uiScaleForViewport(s[1], s[2], false)
		t.truthy(
			scale >= PolishConfig.scale.min and scale <= PolishConfig.scale.max,
			`skala batas {s[1]}x{s[2]}`
		)
		t.truthy(scale >= last - 1e-9, `skala monoton {s[1]}x{s[2]}`)
		last = scale
		local touch = AtmosphereMath.uiScaleForViewport(s[1], s[2], true)
		t.truthy(touch >= PolishConfig.scale.touchMin, `sentuh min {s[1]}x{s[2]}`)
		t.truthy(
			touch >= scale - 1e-9 or scale < PolishConfig.scale.touchMin,
			`sentuh >= biasa {s[1]}x{s[2]}`
		)
	end
	t.near(AtmosphereMath.uiScaleForViewport(1920, 1080, false), 1, 1e-9, "1080p = 1.0")
	t.near(AtmosphereMath.uiScaleForViewport(320, 480, false), 0.62, 1e-9, "min 0.62")
	t.near(AtmosphereMath.uiScaleForViewport(3840, 2160, false), 1.15, 1e-9, "max 1.15")
	t.near(AtmosphereMath.uiScaleForViewport(0, 0, false), 0.62, 1e-9, "nol aman")
end
