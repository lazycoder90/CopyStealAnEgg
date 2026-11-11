--!strict
-- Konfigurasi event Starwhale (docs/PLAN.md 4.11, disederhanakan per docs/CHANGES.md #15).
-- Tanpa tipe Roblox supaya bisa dites di Lune.

local Layout = require("./Layout")

export type Offer = {
	id: string,
	name: string,
	desc: string,
	price: number, -- Stardust
	needsEgg: boolean?, -- true = butuh targetUid (telur placed milik sendiri)
	boostField: string?, -- field boosts.<x> yang diperpanjang
	boostSeconds: number?,
}

local StarwhaleConfig = {}

-- Jadwal (detik waktu-game; Clock.every1Hz).
StarwhaleConfig.intervalSeconds = 2400
StarwhaleConfig.firstDelaySeconds = 900
StarwhaleConfig.stayingSeconds = 290
StarwhaleConfig.statePushSeconds = 5
StarwhaleConfig.zoneMin = 2
StarwhaleConfig.zoneMax = 10

-- Posisi paus: di dalam lane, x = +-laneXMin..laneXMax, z di sekitar tengah zona.
StarwhaleConfig.laneXMin = 30
StarwhaleConfig.laneXMax = 45
StarwhaleConfig.zJitter = 30
StarwhaleConfig.hoverY = 16

-- Pencarian dan telur aneh.
StarwhaleConfig.foundRadius = 35 -- jarak (bidang XZ) pemain berkompas ke paus agar "Found"
StarwhaleConfig.oddCount = 3
StarwhaleConfig.oddRadius = 60 -- telur aneh maksimal sejauh ini dari paus
StarwhaleConfig.oddMinFromWhale = 10
StarwhaleConfig.oddSpacing = 12
StarwhaleConfig.oddY = 1.6 -- tinggi pusat telur di atas lantai (lantai lane di y = 0)
StarwhaleConfig.oddEdgeInset = 6
StarwhaleConfig.collectClientRadius = 6
StarwhaleConfig.collectServerRadius = 12

-- Pod Stardust.
StarwhaleConfig.podCount = 6
StarwhaleConfig.podHp = 3
StarwhaleConfig.podRingRadius = 15
StarwhaleConfig.podMaxPerPlayer = 3
StarwhaleConfig.podReach = 22 -- jarak maksimal pemain ke pod saat memukul
StarwhaleConfig.podHoldSeconds = 0.3
StarwhaleConfig.stardustMin = 1
StarwhaleConfig.stardustMax = 4

-- Nama prompt dan tool (klien mencocokkan prompt berdasarkan nama).
StarwhaleConfig.promptName = "TalkToTilly"
StarwhaleConfig.podPromptName = "CrackPod"
StarwhaleConfig.compassToolName = "Star Compass"
StarwhaleConfig.modalRelay = "RelayPuzzle"
StarwhaleConfig.modalTrade = "TillyTrade"

StarwhaleConfig.puzzleSize = 5

-- Kompas klien: jarak -> selang kedip (detik).
StarwhaleConfig.blinkFast = 0.15
StarwhaleConfig.blinkSlow = 1.2
StarwhaleConfig.blinkFarDistance = 300

-- Kios Tilly (Signal Tower) di hub.
StarwhaleConfig.stall = { x = Layout.hubStalls.tilly.x, z = Layout.hubStalls.tilly.z }

-- Trade di Tilly. Makhluk Limited ditunda (docs/DEFERRED.md).
StarwhaleConfig.offers = {
	{
		id = "orbital",
		name = "Orbital Mutation",
		desc = "x4 income on one placed egg",
		price = 40,
		needsEgg = true,
	},
	{
		id = "lucky",
		name = "Lucky Potion",
		desc = "2x hatch luck for 10 minutes",
		price = 15,
		boostField = "lucky2xUntil",
		boostSeconds = 600,
	},
	{
		id = "speed",
		name = "Speed Potion",
		desc = "Run faster for 5 minutes",
		price = 15,
		boostField = "speed2xUntil",
		boostSeconds = 300,
	},
	{
		id = "growth",
		name = "Growth Potion",
		desc = "2x egg growth for 10 minutes",
		price = 25,
		boostField = "growth2xUntil",
		boostSeconds = 600,
	},
} :: { Offer }

StarwhaleConfig.offerIds = {} :: { string }
StarwhaleConfig.offerById = {} :: { [string]: Offer }
for _, offer in StarwhaleConfig.offers do
	table.insert(StarwhaleConfig.offerIds, offer.id)
	StarwhaleConfig.offerById[offer.id] = offer
end

return StarwhaleConfig
