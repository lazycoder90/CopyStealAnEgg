--!strict
-- Konfigurasi monetisasi (docs/PLAN.md 4.23). SEMUA id Robux bernilai 0 sampai pemilik game membuatnya
-- di Creator Dashboard: id 0 = fitur nonaktif dengan aman (tombol "Coming soon", tanpa Prompt*).
-- Harga hanya untuk tampilan (Robux); harga sungguhan ditentukan di Dashboard.

local Progression = require("./Progression")

export type Gamepass = { key: string, name: string, desc: string, price: number, id: number }
export type Product = {
	key: string,
	kind: string, -- "skipGrowth" | "growAll" | "wheel" | "cash" | "shield" | "potion" | "trail"
	arg: any, -- skipGrowth: nomor tier; cash: menit income; potion: "speed"|"luck"|"growth"; trail: trailId
	name: string,
	desc: string,
	price: number,
	id: number,
}

local MonetizationConfig = {}

MonetizationConfig.gamepasses = {
	{
		key = "money2x",
		name = "2x Money",
		desc = "Double all pet income, forever.",
		price = 199,
		id = 0,
	},
	{
		key = "speed2x",
		name = "2x Speed",
		desc = "Double your running speed, forever.",
		price = 149,
		id = 0,
	},
	{
		key = "vip",
		name = "VIP",
		desc = "Offline earnings cap doubled.",
		price = 299,
		id = 0,
	},
	{
		key = "equip3",
		name = "+3 Equip",
		desc = "Equip 3 more pets at once.",
		price = 249,
		id = 0,
	},
	{
		key = "lucky",
		name = "Lucky Hatch",
		desc = "Double the mutation luck on every hatch.",
		price = 199,
		id = 0,
	},
	{
		key = "fastGrowth",
		name = "Fast Growth",
		desc = "Eggs grow 1.5x faster, forever.",
		price = 249,
		id = 0,
	},
} :: { Gamepass }

-- Skip Growth bertingkat menurut sisa waktu tumbuh (detik waktu-game). maxSeconds eksklusif.
MonetizationConfig.skipTiers = {
	{ maxSeconds = 300, price = 9 },
	{ maxSeconds = 1800, price = 19 },
	{ maxSeconds = 7200, price = 39 },
	{ maxSeconds = 28800, price = 79 },
	{ maxSeconds = math.huge, price = 129 },
}

-- Kompensasi (menit income) bila pembelian tidak punya target (telur sudah siap/hilang).
MonetizationConfig.compensationMinutes = 5
MonetizationConfig.minCash = 100
MonetizationConfig.receiptKeep = 100

-- Durasi potion dan Shield produk (detik).
MonetizationConfig.potionSeconds = { speed = 300, luck = 600, growth = 600 }
MonetizationConfig.shieldMinutes = 10

local products: { Product } = {}

for tier, info in MonetizationConfig.skipTiers do
	table.insert(products, {
		key = `skip{tier}`,
		kind = "skipGrowth",
		arg = tier,
		name = "Skip Growth",
		desc = "Instantly finish an egg.",
		price = info.price,
		id = 0,
	})
end

local function add(p: Product)
	table.insert(products, p)
end

add({
	key = "growAll",
	kind = "growAll",
	arg = 0,
	name = "Grow All",
	desc = "Instantly finish every growing egg.",
	price = 199,
	id = 0,
})
add({
	key = "wheelPlus1",
	kind = "wheel",
	arg = 1,
	name = "Wheel +1",
	desc = "Sprint Wheel gains one level.",
	price = 99,
	id = 0,
})
add({
	key = "cashSmall",
	kind = "cash",
	arg = 30,
	name = "Small Cash Pack",
	desc = "30 minutes of income.",
	price = 49,
	id = 0,
})
add({
	key = "cashMedium",
	kind = "cash",
	arg = 120,
	name = "Medium Cash Pack",
	desc = "2 hours of income.",
	price = 149,
	id = 0,
})
add({
	key = "cashLarge",
	kind = "cash",
	arg = 480,
	name = "Large Cash Pack",
	desc = "8 hours of income.",
	price = 399,
	id = 0,
})
add({
	key = "shield10",
	kind = "shield",
	arg = 10,
	name = "Shell Shield",
	desc = "Protect your Coop right now.",
	price = 59,
	id = 0,
})
add({
	key = "speedPotion",
	kind = "potion",
	arg = "speed",
	name = "Speed Potion",
	desc = "1.5x speed for 5 minutes.",
	price = 29,
	id = 0,
})
add({
	key = "luckPotion",
	kind = "potion",
	arg = "luck",
	name = "Luck Potion",
	desc = "2x mutation luck for 10 minutes.",
	price = 39,
	id = 0,
})
add({
	key = "growthPotion",
	kind = "potion",
	arg = "growth",
	name = "Growth Potion",
	desc = "Eggs grow 2x faster for 10 minutes.",
	price = 39,
	id = 0,
})

-- Trail berbayar Robux: satu produk per trail yang punya robuxPrice > 0.
for _, trail in Progression.trails do
	if trail.robuxPrice > 0 then
		add({
			key = `trail:{trail.id}`,
			kind = "trail",
			arg = trail.id,
			name = trail.name,
			desc = `x{trail.mult} Speed trail.`,
			price = trail.robuxPrice,
			id = 0,
		})
	end
end

MonetizationConfig.products = products

-- Tab Featured: item pilihan (type "gamepass" | "product", key).
MonetizationConfig.featured = {
	{ type = "gamepass", key = "speed2x" },
	{ type = "gamepass", key = "money2x" },
	{ type = "product", key = "cashLarge" },
	{ type = "product", key = "growAll" },
}

-- Penawaran pemain baru (ditunda; hanya teks).
-- Timestamp unix (detik) update berikutnya untuk papan NEXT UPDATE. 0 = belum diketahui.
MonetizationConfig.nextUpdateAt = 0

function MonetizationConfig.getProduct(key: string): Product?
	for _, p in products do
		if p.key == key then
			return p
		end
	end
	return nil
end

function MonetizationConfig.getGamepass(key: string): Gamepass?
	for _, g in MonetizationConfig.gamepasses do
		if g.key == key then
			return g
		end
	end
	return nil
end

return MonetizationConfig
