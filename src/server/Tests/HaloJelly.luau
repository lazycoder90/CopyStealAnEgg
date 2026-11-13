--!nonstrict
-- Uji Halo Jelly: model kubus, migrasi id lama, jalur telur -> pet.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "HaloJelly")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local ModelFactory = require(Shared.ModelFactory)
local Types = require(Shared.Types)

return function(T)
	local creature = Creatures.get("halo_jelly")
	T.check("halo_jelly ada di zona 1 slot 5", creature.zone == 1 and creature.slot == 5)

	local model = ModelFactory.makeCreature(creature, creature.baseKg, nil)
	local parts, glow = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.Material == Enum.Material.Neon then
				glow += 1
			end
		end
	end
	T.check("model punya 205 Part (204 kubus + Body)", parts == 205, tostring(parts))
	T.check("114 bagian Neon", glow == 114, tostring(glow))
	T.check("PrimaryPart Body", model.PrimaryPart and model.PrimaryPart.Name == "Body")
	T.check(
		"atribut rarity di Body",
		model.PrimaryPart:GetAttribute(Types.Attr.Rarity) == creature.rarity
	)

	local size = model:GetExtentsSize()
	local s = math.clamp(0.9 * (creature.baseKg ^ (1 / 3)), 0.9, 6)
	T.check("tinggi ~2.4*s", math.abs(size.Y - 2.4 * s) < 0.3, `{size.Y} vs {2.4 * s}`)

	local mid = model:GetBoundingBox()
	T.check(
		"pivot di pusat extents",
		(mid.Position - model.PrimaryPart.Position).Magnitude < 0.3,
		tostring((mid.Position - model.PrimaryPart.Position).Magnitude)
	)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.CanCollide or not d.Anchored) then
			T.check("semua Part anchored dan tanpa tabrakan", false, d:GetFullName())
			break
		end
	end
	model:Destroy()

	local tinted = ModelFactory.makeCreature(creature, 1, { "Moonlit" })
	T.check("mutasi menghasilkan model", tinted.PrimaryPart ~= nil)
	tinted:Destroy()

	local egg = ModelFactory.makeEgg(creature, 1)
	T.check("telur dapat dibuat", egg.PrimaryPart ~= nil)
	egg:Destroy()

	local data = {
		eggs = { a = { id = "acorn_squirrel" } },
		pets = {},
		index = { found = {}, claimed = {} },
	}
	T.check(
		"migrasi id lama",
		Creatures.migrateProfile(data) == 1 and data.eggs.a.id == "halo_jelly"
	)
end
