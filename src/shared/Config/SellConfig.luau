--!strict
-- Konstanta kios SELL dan panel Sell/Inventaris/Growing Eggs (docs/PLAN.md §3.11, §4.19, §4.20).
-- Murni data (tanpa tipe Roblox) supaya bisa dites di Lune.

local Layout = require("./Layout")

local SellConfig = {}

-- Kios di hub (posisi dari Layout.hubStalls.sell).
SellConfig.stall = { x = Layout.hubStalls.sell.x, y = 0, z = Layout.hubStalls.sell.z }
SellConfig.stallName = "SellStall"
SellConfig.promptName = "SellStallPrompt"
SellConfig.promptText = "Sell Items"
SellConfig.signText = "SELL"

-- Batas jumlah uid per permintaan jual.
SellConfig.maxPerRequest = 100
-- Rarity minimal (indeks) yang memicu dialog konfirmasi (Mythic = 6).
SellConfig.confirmMinRarity = 6

-- Nama modal klien.
SellConfig.modalSell = "Sell"
SellConfig.modalInventory = "Inventory"
SellConfig.modalGrowing = "GrowingEggs"

-- Jarak target Place dari pemain (sama dengan PlacementController).
SellConfig.placeLookDistance = 7

-- Label tombol HUD.
SellConfig.bagButton = "Bag"
SellConfig.eggsButton = "Eggs"

-- Baris info Gear (statis).
SellConfig.gearInfo = {
	{ name = "Frying Pan", detail = "Bonk thieves and guardians. Equipped in your hotbar." },
	{
		name = "Sticky Yolk Trap",
		detail = "Place it on your Coop to trap thieves. Buy from the shop.",
	},
}
-- Nama boost yang tampil di Gear.
SellConfig.boostNames = {
	growth2xUntil = "2x Egg Growth",
	lucky2xUntil = "2x Luck",
	speed2xUntil = "Speed Potion",
}
SellConfig.boostOrder = { "growth2xUntil", "lucky2xUntil", "speed2xUntil" }

return SellConfig
