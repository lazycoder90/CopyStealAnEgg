--!strict
-- 10 tier rarity (docs/PLAN.md §1.3 dan §3.3). Tanpa tipe Roblox supaya bisa dites di Lune.

export type Rarity = {
	name: string,
	rgb: { number },
	incomeMult: number,
	hatchBase: number, -- detik
	announce: boolean, -- diumumkan ke seluruh server saat spawn/hatch
}

local Rarities = {}

Rarities.list = {
	{ name = "Common", rgb = { 184, 184, 184 }, incomeMult = 1, hatchBase = 10, announce = false },
	{
		name = "Uncommon",
		rgb = { 107, 214, 107 },
		incomeMult = 3,
		hatchBase = 20,
		announce = false,
	},
	{ name = "Rare", rgb = { 79, 163, 255 }, incomeMult = 8, hatchBase = 45, announce = false },
	{ name = "Epic", rgb = { 194, 91, 255 }, incomeMult = 20, hatchBase = 90, announce = false },
	{
		name = "Legendary",
		rgb = { 255, 196, 61 },
		incomeMult = 50,
		hatchBase = 180,
		announce = true,
	},
	{ name = "Mythic", rgb = { 255, 75, 75 }, incomeMult = 120, hatchBase = 360, announce = true },
	{ name = "Astral", rgb = { 122, 92, 255 }, incomeMult = 300, hatchBase = 900, announce = true },
	{ name = "Void", rgb = { 40, 200, 220 }, incomeMult = 800, hatchBase = 1800, announce = true },
	{
		name = "Timeless",
		rgb = { 255, 138, 216 },
		incomeMult = 2000,
		hatchBase = 3600,
		announce = true,
	},
	{
		name = "Primordial",
		rgb = { 255, 255, 255 },
		incomeMult = 5000,
		hatchBase = 7200,
		announce = true,
	},
} :: { Rarity }

Rarities.count = #Rarities.list

function Rarities.get(index: number): Rarity
	local r = Rarities.list[index]
	assert(r, "rarity tidak ada: " .. tostring(index))
	return r
end

return Rarities
