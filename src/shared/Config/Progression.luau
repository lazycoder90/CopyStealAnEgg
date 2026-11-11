--!strict
-- Progresi: Pen, slot equip, ekspansi, Sprint Wheel, Trail (docs/PLAN.md §3.7-3.10).

export type PenLevel = { price: number, eggSlots: number, visiblePets: number }
export type Trail = {
	id: string,
	name: string,
	rarity: string,
	mult: number,
	cashPrice: number,
	robuxPrice: number, -- 0 = tidak dijual dengan Robux
	color: { number }, -- warna efek Trail (RGB 0..255)
}

local Progression = {}

Progression.pen = {
	[1] = { price = 0, eggSlots = 4, visiblePets = 3 },
	[2] = { price = 1e6, eggSlots = 5, visiblePets = 4 },
	[3] = { price = 75e6, eggSlots = 6, visiblePets = 5 },
	[4] = { price = 1e9, eggSlots = 7, visiblePets = 6 },
	[5] = { price = 15e9, eggSlots = 8, visiblePets = 7 },
	[6] = { price = 200e9, eggSlots = 9, visiblePets = 8 },
	[7] = { price = 1.5e12, eggSlots = 10, visiblePets = 9 },
	[8] = { price = 8e12, eggSlots = 11, visiblePets = 10 },
	[9] = { price = 30e12, eggSlots = 12, visiblePets = 11 },
	[10] = { price = 100e12, eggSlots = 13, visiblePets = 12 },
	[11] = { price = 500e12, eggSlots = 14, visiblePets = 14 },
} :: { [number]: PenLevel }
Progression.maxPenLevel = 11

Progression.equipSlotPrices = {
	[4] = 5e3,
	[5] = 5e4,
	[6] = 5e5,
	[7] = 3e6,
	[8] = 15e6,
	[9] = 40e6,
	[10] = 75e6,
	[11] = 500e6,
	[12] = 50e9,
	[13] = 500e12,
	[14] = 5e15,
} :: { [number]: number }
Progression.startEquipSlots = 3
Progression.maxEquipSlots = 14

-- "Unlock: $1K": +1 slot telur (muncul di tutorial).
Progression.plotExpansion = { price = 1000, extraEggSlots = 1 }

-- Rumus gain/harga ada di Formulas.
Progression.wheel = { maxLevel = 30, stepsPerSecond = 3 }

-- Kios Trail di hub: nama prompt dipakai klien untuk membuka toko (tanpa remote).
Progression.trailShop = { promptName = "TrailsShopPrompt", x = -60, y = 0, z = 95 }

Progression.trails = {
	{
		id = "dust_puff",
		name = "Dust Puff",
		rarity = "Common",
		mult = 1.25,
		cashPrice = 2e3,
		robuxPrice = 0,
		color = { 200, 184, 150 },
	},
	{
		id = "leaf_swirl",
		name = "Leaf Swirl",
		rarity = "Uncommon",
		mult = 1.5,
		cashPrice = 40e3,
		robuxPrice = 0,
		color = { 107, 214, 107 },
	},
	{
		id = "bubble_stream",
		name = "Bubble Stream",
		rarity = "Rare",
		mult = 2,
		cashPrice = 600e3,
		robuxPrice = 0,
		color = { 79, 163, 255 },
	},
	{
		id = "spark_ribbon",
		name = "Spark Ribbon",
		rarity = "Epic",
		mult = 2.75,
		cashPrice = 5e6,
		robuxPrice = 49,
		color = { 194, 91, 255 },
	},
	{
		id = "sunflare",
		name = "Sunflare",
		rarity = "Legendary",
		mult = 3.5,
		cashPrice = 30e6,
		robuxPrice = 79,
		color = { 255, 196, 61 },
	},
	{
		id = "ember_comet",
		name = "Ember Comet",
		rarity = "Mythic",
		mult = 4,
		cashPrice = 750e6,
		robuxPrice = 119,
		color = { 255, 75, 75 },
	},
	{
		id = "astral_wake",
		name = "Astral Wake",
		rarity = "Astral",
		mult = 5,
		cashPrice = 20e9,
		robuxPrice = 199,
		color = { 122, 92, 255 },
	},
	{
		id = "void_glitch",
		name = "Void Glitch",
		rarity = "Void",
		mult = 7,
		cashPrice = 500e9,
		robuxPrice = 349,
		color = { 40, 200, 220 },
	},
	{
		id = "timeless_bloom",
		name = "Timeless Bloom",
		rarity = "Timeless",
		mult = 10,
		cashPrice = 12.5e12,
		robuxPrice = 499,
		color = { 255, 138, 216 },
	},
	{
		id = "primordial_prism",
		name = "Primordial Prism",
		rarity = "Primordial",
		mult = 14,
		cashPrice = 250e12,
		robuxPrice = 799,
		color = { 255, 255, 255 },
	},
	{
		id = "prismatic_crown",
		name = "Prismatic Crown",
		rarity = "Primordial",
		mult = 20,
		cashPrice = 5e15,
		robuxPrice = 1100,
		color = { 255, 240, 170 },
	},
} :: { Trail }

function Progression.eggSlotsFor(penLevel: number, plotExpansion: number): number
	local pen = Progression.pen[penLevel]
	assert(pen, "pen level tidak ada: " .. tostring(penLevel))
	return pen.eggSlots + Progression.plotExpansion.extraEggSlots * plotExpansion
end

function Progression.visiblePetsFor(penLevel: number): number
	local pen = Progression.pen[penLevel]
	assert(pen, "pen level tidak ada: " .. tostring(penLevel))
	return pen.visiblePets
end

return Progression
