--!strict
-- Konfigurasi polish Wave 5: tabel suara, parameter atmosfer, batas skala UI, juice.
-- Hanya aset suara bawaan Roblox yang aman (docs/CONTRACTS.md). Tanpa tipe Roblox agar bisa dites di Lune.

local PolishConfig = {}

-- Nama suara -> { id, volume, speed }. Variasi didapat dari PlaybackSpeed.
local SOUND_PATH = "rbxasset://sounds/"
PolishConfig.soundPath = SOUND_PATH
PolishConfig.poolSize = 6
PolishConfig.sounds = {
	grab = { id = "action_get_up.mp3", volume = 0.6, speed = 1.3 },
	place = { id = "action_jump_land.mp3", volume = 0.6, speed = 0.9 },
	drop = { id = "action_jump_land.mp3", volume = 0.5, speed = 0.7 },
	hatch = { id = "impact_water.mp3", volume = 0.6, speed = 1.1 },
	hatch_rare = { id = "impact_explosion_03.mp3", volume = 0.35, speed = 1.6 },
	claim = { id = "volume_slider.ogg", volume = 0.6, speed = 1.4 },
	ui_click = { id = "volume_slider.ogg", volume = 0.4, speed = 0.8 },
	caught = { id = "ouch.ogg", volume = 0.7, speed = 1 },
	bonk = { id = "oof.ogg", volume = 0.7, speed = 1 },
	trap = { id = "impact_water.mp3", volume = 0.6, speed = 0.6 },
	race_go = { id = "action_jump.mp3", volume = 0.6, speed = 1.5 },
	error = { id = "volume_slider.ogg", volume = 0.5, speed = 0.5 },
}

-- Atmosfer. Warna dalam RGB 0..255. Nilai di hub = netral cerah hangat.
PolishConfig.atmosphere = {
	tweenSeconds = 2,
	updateHz = 4,
	hub = {
		haze = { 255, 244, 226 },
		hazeDensity = 0.25,
		hazeOffset = 0.1,
		glare = 0,
		tint = { 255, 248, 238 },
		brightness = 0.02,
		contrast = 0.05,
		saturation = 0.1,
		bloomIntensity = 0.2,
		bloomSize = 24,
		bloomThreshold = 1.1,
		sunRays = 0.06,
	},
	-- Pewarnaan per zona: { tint RGB, saturation, contrast, brightness }. Zona tanpa entri
	-- memakai tint turunan dari floorRgb.
	zoneGrade = {
		[3] = { { 255, 236, 244 }, 0.18, 0.06, 0.0 }, -- Canopy: sedikit pink
		[4] = { { 255, 226, 180 }, 0.12, 0.08, 0.03 }, -- Desert: hangat
		[5] = { { 214, 232, 255 }, -0.02, 0.06, 0.04 }, -- Snow: dingin
		[6] = { { 255, 190, 160 }, 0.16, 0.14, -0.03 }, -- Caldera: merah hangat
		[7] = { { 170, 205, 255 }, 0.08, 0.1, -0.04 }, -- Abyss: biru
		[9] = { { 255, 214, 232 }, 0.2, 0.06, 0.0 }, -- Grove: pink
		[10] = { { 200, 180, 255 }, 0.1, 0.1, -0.04 }, -- Crater: ungu
		[12] = { { 190, 160, 230 }, -0.08, 0.2, -0.08 }, -- Gloomrift: gelap ungu
	},
	-- Batas wajar (dipakai tes).
	bounds = {
		density = { 0.25, 0.4 },
		bloomIntensity = { 0.1, 0.5 },
		saturation = { -0.2, 0.3 },
		contrast = { 0, 0.3 },
		brightness = { -0.1, 0.1 },
	},
}

-- Skala UI.
PolishConfig.scale = {
	baseHeight = 1080,
	baseWidth = 1440, -- layar sempit (potret) ikut mengecil
	min = 0.62,
	max = 1.15,
	touchMultiplier = 1.1,
	touchMin = 0.75, -- tombol 44 px tetap terbaca
}

-- Juice.
PolishConfig.juice = {
	cashMinFraction = 0.005,
	cashThrottle = 0.4,
	cashPopScale = 1.12,
	cashPopSeconds = 0.25,
	rareMinRarity = 5,
	rareRadius = 60,
	rareScanSeconds = 0.5,
	rareMaxHighlights = 6,
	carryPulseHz = 1.4,
	carrySaturation = 0.12,
	carryContrast = 0.06,
}

-- Sinematik intro.
PolishConfig.cinematic = {
	seconds = 5,
	skipAfter = 1,
	characterWait = 10,
	highHeight = 140, -- tinggi kamera awal di atas karakter
	backDistance = 120,
}

-- Server: bendera cinematicSeen diset setelah sekian detik profil baru bergabung.
PolishConfig.cinematicSeenDelay = 40

return PolishConfig
