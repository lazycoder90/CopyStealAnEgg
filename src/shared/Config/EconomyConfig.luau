--!strict
-- Konfigurasi ekonomi lanjutan: penghasilan offline, Free Basket, Friend Boost, Leaderboard.
-- Murni data/angka (bisa dites di Lune). Posisi kios/papan ada di Layout.hubStalls.

local EconomyConfig = {}

-- Penghasilan offline (docs/PLAN.md 3.11).
EconomyConfig.offline = {
	capHours = 24,
	penBonusLevel = 8, -- pen level ini ke atas menambah jam cap
	penBonusHours = 12,
	minBannerSeconds = 60, -- banner hanya jika pemain pergi selama ini atau lebih
}

-- Free Basket: bobot hadiah dan durasi efek (detik).
EconomyConfig.basket = {
	promptName = "FreeBasketPrompt",
	cooldown = 900,
	cashSeconds = 180, -- hadiah uang = 3 menit income
	cashMin = 50,
	speedSeconds = 300,
	growthSeconds = 300,
	luckSeconds = 600,
	luckMult = 2,
	-- urutan = urutan bobot (dipakai BasketRoll)
	rewards = {
		{ kind = "cash", weight = 60 },
		{ kind = "speed", weight = 20 },
		{ kind = "growth", weight = 15 },
		{ kind = "luck", weight = 5 },
	},
}

EconomyConfig.friend = {
	perFriend = 0.1, -- +10% income per teman di server
	max = 0.5,
}

EconomyConfig.leaderboard = {
	leaderstatsName = "leaderstats",
	statSpeed = "Speed",
	statMoney = "Money/s",
	moneyStore = "TopMoneyPerSec_v1",
	trophyStore = "TopTrophies_v1",
	rows = 10,
	statInterval = 1, -- detik
	writeInterval = 120,
	readInterval = 60,
	minChange = 0.01, -- tulis ulang hanya jika berubah >= 1%
	backoff = { 1, 2, 4, 8 }, -- detik
	giveUpSeconds = 300,
	moneyBoardName = "BoardMoney",
	trophyBoardName = "BoardTrophy",
	moneyTitle = "TOP BANDITS - MONEY/S",
	trophyTitle = "MOST TROPHIES",
	boardY = 18,
}

-- Bonus income teman: jumlah teman -> tambahan aditif (0..max).
function EconomyConfig.friendBoost(friendCount: number): number
	local n = math.max(0, math.floor(friendCount))
	return math.min(n * EconomyConfig.friend.perFriend, EconomyConfig.friend.max)
end

return EconomyConfig
