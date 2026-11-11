--!strict
-- Badge Roblox. Semua id 0 sampai dibuat di Creator Dashboard: id 0 = badge hanya tercatat di profil
-- (tanpa panggilan AwardBadge).

export type Badge = { key: string, name: string, desc: string, id: number }

local BadgeConfig = {}

BadgeConfig.list = {
	{ key = "FirstHatch", name = "First Hatch", desc = "Hatch your first egg.", id = 0 },
	{ key = "FirstSteal", name = "First Steal", desc = "Place an egg you stole.", id = 0 },
	{ key = "Zone5", name = "Zone 5 Explorer", desc = "Reach zone 5.", id = 0 },
	{ key = "Zone9", name = "Zone 9 Explorer", desc = "Reach zone 9.", id = 0 },
	{ key = "Zone12", name = "Zone 12 Explorer", desc = "Reach zone 12.", id = 0 },
	{ key = "IndexZone", name = "Index Master", desc = "Complete a zone in the Index.", id = 0 },
	{ key = "RaceWinner", name = "Race Winner", desc = "Win trophies in a race.", id = 0 },
	{ key = "StarwhaleVisitor", name = "Starwhale Visitor", desc = "Fix the relay.", id = 0 },
	{ key = "BudElder", name = "Bud Elder", desc = "Raise Bud to Elder.", id = 0 },
} :: { Badge }

BadgeConfig.byKey = {} :: { [string]: Badge }
for _, badge in BadgeConfig.list do
	BadgeConfig.byKey[badge.key] = badge
end

-- Zona yang memicu badge Zone N.
BadgeConfig.zoneBadges =
	{ { zone = 5, key = "Zone5" }, { zone = 9, key = "Zone9" }, { zone = 12, key = "Zone12" } }

return BadgeConfig
