--!strict
-- Konfigurasi event dunia Wave 4: siang/malam, Egg Reset, aturan pengumuman, dan quest Bud (companion).
-- Tanpa tipe Roblox supaya bisa dites di Lune.

export type Quest = {
	key: string, -- kunci progres di data.companion.progress
	text: string,
	event: string, -- "EggGrabbed" | "EggPlaced" | "EggHatched"
	target: number,
	zone: number?, -- hanya zona ini
	minRarity: number?, -- rarity >= nilai ini
	stolen: boolean?, -- EggPlaced: harus telur curian
}

export type Stage = {
	name: string,
	reward: string, -- teks hadiah untuk UI
	incomeBonus: number, -- aditif (0.05 = +5%)
	speedMult: number, -- pengali speed (1 = tidak ada)
	quests: { Quest },
}

local EventsConfig = {}

EventsConfig.dayNight = {
	daySeconds = 240,
	nightSeconds = 90,
	nightGrowthMultiplier = 30,
	broadcastEvery = 10, -- detik waktu-game
	dayClockTime = 14,
	nightClockTime = 24, -- 24 == 0 (tengah malam)
	rampSeconds = 8, -- lama peralihan gelap/terang di awal fase
	countdownSeconds = 10, -- BigCountdown di klien
}

EventsConfig.eggReset = {
	intervalSeconds = 600,
	countdownBroadcastSeconds = 10, -- siaran tiap detik pada sekian detik terakhir
	hudBigSeconds = 5, -- BigCountdown klien pada sekian detik terakhir
	broadcastEvery = 10,
}
EventsConfig.resetIntervalSeconds = EventsConfig.eggReset.intervalSeconds

EventsConfig.announce = {
	bootIgnoreSeconds = 20, -- abaikan spawn awal setelah Start
	maxPerBatch = 6,
	bufferSeconds = 1,
	logSize = 40,
}

EventsConfig.feed = {
	maxRows = 3,
	lifetime = 6,
	topOffset = 96,
}

EventsConfig.companion = {
	maxStage = 4,
}

EventsConfig.stages = {
	{
		name = "Seed",
		reward = "+5% income",
		incomeBonus = 0.05,
		speedMult = 1,
		quests = {
			{
				key = "s1_grab_meadow",
				text = "Grab 20 Mossy Meadow eggs",
				event = "EggGrabbed",
				target = 20,
				zone = 1,
			},
			{ key = "s1_hatch", text = "Hatch 5 eggs", event = "EggHatched", target = 5 },
		},
	},
	{
		name = "Sprout",
		reward = "+5% speed",
		incomeBonus = 0,
		speedMult = 1.05,
		quests = {
			{
				key = "s2_grab_canopy",
				text = "Grab 15 Canopy Tangle eggs",
				event = "EggGrabbed",
				target = 15,
				zone = 3,
			},
			{
				key = "s2_hatch_frost",
				text = "Hatch a Frostpeak creature",
				event = "EggHatched",
				target = 1,
				zone = 5,
			},
		},
	},
	{
		name = "Bloom",
		reward = "+10% income",
		incomeBonus = 0.10,
		speedMult = 1,
		quests = {
			{
				key = "s3_steal",
				text = "Steal 5 eggs from other players",
				event = "EggPlaced",
				target = 5,
				stolen = true,
			},
			{
				key = "s3_hatch_astral",
				text = "Hatch any Astral or better",
				event = "EggHatched",
				target = 1,
				minRarity = 7,
			},
		},
	},
	{
		name = "Elder",
		reward = "+5% income and a fully grown Bud",
		incomeBonus = 0.05,
		speedMult = 1,
		quests = {
			{
				key = "s4_grab_timeless",
				text = "Grab any Timeless egg",
				event = "EggGrabbed",
				target = 1,
				minRarity = 9,
			},
		},
	},
} :: { Stage }

-- Rarity minimum untuk pengumuman hatch (Rarities.announce tetap penentu akhir).
EventsConfig.hatchAnnounceMinRarity = 5

return EventsConfig
