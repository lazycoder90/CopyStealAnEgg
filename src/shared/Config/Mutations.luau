--!strict
-- Mutasi (docs/PLAN.md §1.4). Mult ditambahkan, bukan dikalikan (lihat MutationLogic.mult).

export type Mutation = {
	mult: number,
	hatchChance: number?,
	npcSuccess: number?,
	npcPriceMult: number?,
	source: string?,
}

local Mutations = {}

Mutations.list = {
	Pearl = { mult = 1.5, hatchChance = 0.04, npcSuccess = 0.70, npcPriceMult = 30 },
	Amber = { mult = 2, hatchChance = 0.015, npcSuccess = 0.45, npcPriceMult = 80 },
	Starlit = { mult = 3, hatchChance = 0.004, npcSuccess = 0.20, npcPriceMult = 250 },
	Moonlit = { mult = 2.5, source = "night" },
	Orbital = { mult = 4, source = "stardust" },
	Prism = { mult = 6, source = "fuse" },
} :: { [string]: Mutation }

Mutations.maxPerItem = 3
Mutations.order = { "Pearl", "Amber", "Starlit", "Moonlit", "Orbital", "Prism" }
Mutations.moonlitChancePerNight = 0.04

return Mutations
