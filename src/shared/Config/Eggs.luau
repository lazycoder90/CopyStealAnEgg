--!strict
-- Aturan telur dunia, carry, dan penempatan (docs/PLAN.md §3.2, §4.1, §4.2).

local Eggs = {}

-- Bobot pemilihan slot makhluk.
Eggs.smallNestWeights = { 35, 25, 18, 14, 8 } -- slot 1..5
Eggs.grandNestWeights = { 75, 22, 3 } -- slot 6..8
Eggs.luckSlotBoostFrom = 4 -- luck mengalikan bobot slot >= ini

Eggs.smallNestsPerZone = 10
Eggs.grandNestsPerZone = 1
Eggs.smallNestRespawn = 45 -- detik
Eggs.worldEggReturnTime = 15 -- telur jatuh di lane kembali ke nest setelah ini
Eggs.stolenEggReturnTime = 20

-- Interaksi.
Eggs.grabHoldDuration = 0.3
Eggs.grabMaxDistance = 10
Eggs.grabValidateSlack = 6 -- toleransi jarak validasi server (stud)
Eggs.hatchMaxDistance = 12
Eggs.hatchRemoteDistance = 80 -- hatch dari panel Growing Eggs

-- Penempatan di Coop.
Eggs.placeMaxDistanceFromCoop = 14
Eggs.placeMinSpacing = 6
Eggs.placeInset = 3 -- jarak minimal dari tepi plot
Eggs.pocketCapacity = 15
Eggs.petCapacity = 250

-- Telur tutorial.
Eggs.tutorialSpeciesId = "moss_pup"
Eggs.tutorialGrowSeconds = 3

-- Pesan galat penempatan (teks persis dari spesifikasi).
Eggs.messages = {
	tooFar = "Get closer to your area to place an egg!",
	badSpot = "Cannot place egg here!",
	tooClose = "Egg is too close to another egg!",
	coopFull = "Your Coop is full! Upgrade your Coop.",
	notCarrying = "You are not carrying an egg.",
	alreadyCarrying = "You are already carrying an egg!",
	petStorageFull = "Pet storage full! Sell some pets.",
}

return Eggs
