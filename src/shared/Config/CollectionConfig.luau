--!strict
-- Konstanta fitur koleksi (Wave 3): Pet Index, Fuse Machine, Yolk Lab (mutasi NPC).
-- Murni angka/string supaya bisa dites di Lune; posisi kios diambil dari Layout.hubStalls.

local Layout = require("./Layout")

local CollectionConfig = {}

CollectionConfig.index = {
	cashRewardMult = 120, -- cash = baseIncome * 120 per spesies
	speedRewardFactor = 0.0005, -- docs/ECONOMY.md rekomendasi #2 (bukan 0.02)
	speedRewardBase = 5, -- speed dasar spesies slot 1 (zona 1 recSpeed = 0 butuh dasar)
	zoneBonusIncome = 0.02, -- +2% income per zona lengkap (aditif)
	-- Makhluk Limited: belum bisa didapat (tidak masuk Creatures), tampil terkunci "Coming soon".
	limited = { "Starwhale Calf", "Stardust Axolotl", "Comet Courier Pigeon", "Sproutling Elder" },
}

CollectionConfig.fuse = {
	promptName = "FuseMachinePrompt",
	x = Layout.hubStalls.fuse.x,
	y = 0,
	z = Layout.hubStalls.fuse.z,
	petCount = 3,
}

CollectionConfig.mutation = {
	promptName = "YolkLabPrompt",
	x = Layout.hubStalls.mutation.x,
	y = 0,
	z = Layout.hubStalls.mutation.z,
	options = { "Pearl", "Amber", "Starlit" },
	cancelToken = "cancel",
	pendingSeconds = 30, -- waktu nyata pilihan mutasi berlaku
}

return CollectionConfig
