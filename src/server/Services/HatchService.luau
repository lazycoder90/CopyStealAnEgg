--!nonstrict
-- HatchService: menetaskan telur yang sudah siap menjadi pet.
-- Atomik di satu fungsi tanpa yield: telur dihapus, pet dibuat, Index ditandai, pet dipasang otomatis.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local MutationLogic = require(Shared.Logic.MutationLogic)
local PetMath = require(Shared.Logic.PetMath)
local RNG = require(Shared.Logic.RNG)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local HatchService = {}

local rng = RNG.new(os.time() + 17)
local luckProviders = {} -- [name] = function(userId) -> number (pengali peluang mutasi)

function HatchService.setSeed(seed: number)
	rng:reseed(seed)
end

function HatchService.addLuckProvider(name: string, fn: (number) -> number)
	luckProviders[name] = fn
end

local function luckMult(userId: number): number
	local m = 1
	for _, fn in luckProviders do
		m *= fn(userId)
	end
	return m
end

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

-- Mengembalikan true + payload HatchReveal, atau false + pesan galat.
function HatchService.hatch(userId: number, eggUid: string): (boolean, any)
	local data = DataService.getByUserId(userId)
	local egg = data and data.eggs[eggUid]
	if not egg or egg.loc ~= "placed" then
		return false, "Egg not found."
	end
	if egg.progress < egg.growTotal then
		return false, "This egg is not ready yet."
	end
	if PetService.petCount(data) >= Eggs.petCapacity then
		return false, Eggs.messages.petStorageFull
	end

	local creature = Creatures.get(egg.id)

	-- Mutasi: bawaan telur + hasil roll saat menetas (maks 3, unik).
	local muts = table.clone(egg.muts or {})
	for _, name in MutationLogic.rollOnHatch(rng, luckMult(userId)) do
		muts = MutationLogic.add(muts, name)
	end

	local petUid = newUid()
	local pet = {
		id = egg.id,
		kg = egg.kg,
		g = if rng:chance(0.5) then "M" else "F",
		muts = muts,
		eq = false,
		lock = false,
		t = Clock.now(),
	}

	-- Hapus telur (data, model, replikasi), tambah pet.
	data.eggs[eggUid] = nil
	GrowthService.removeModel(userId, eggUid)
	StateReplicator.set(userId, `eggs.{eggUid}`, nil)
	PetService.addPet(userId, petUid, pet)

	local isNew = not data.index.found[creature.id]
	if isNew then
		data.index.found[creature.id] = true
		StateReplicator.set(userId, `index.found.{creature.id}`, true)
	end
	data.stats.hatched = (data.stats.hatched or 0) + 1
	StateReplicator.set(userId, "stats.hatched", data.stats.hatched)

	PetService.equip(userId, petUid) -- gagal bila slot penuh: tidak apa-apa

	local payload = {
		petUid = petUid,
		speciesId = creature.id,
		name = creature.name,
		rarity = creature.rarity,
		muts = muts,
		kg = egg.kg,
		gender = pet.g,
		income = PetMath.petIncome(creature.id, egg.kg, muts),
		isNew = isNew,
	}
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("HatchReveal", player, payload)
	end
	GameEvents.EggHatched:Fire({
		userId = userId,
		petUid = petUid,
		speciesId = creature.id,
		rarity = creature.rarity,
		zone = creature.zone,
		isNew = isNew,
	})
	return true, payload
end

local function notify(player: Player, message: string)
	Net.fire("Notify", player, message, "error")
end

function HatchService.Init()
	TestBridge.register("hatch.hatch", function(userId, eggUid)
		local ok, result = HatchService.hatch(userId, eggUid)
		return { ok = ok, result = result }
	end)
	TestBridge.register("hatch.seed", function(seed)
		HatchService.setSeed(seed)
		return true
	end)
end

function HatchService.Start()
	-- Hatch lewat prompt di model telur: harus pemilik dan dekat.
	GrowthService.onHatchRequested:Connect(function(player, eggUid)
		local userId = player.UserId
		local model = GrowthService.getModel(userId, eggUid)
		local root = Actors.getRoot(userId)
		if not (model and root) then
			return
		end
		local distance = (root.Position - model:GetPivot().Position).Magnitude
		if distance > Eggs.hatchMaxDistance + 6 then
			notify(player, "Too far away.")
			return
		end
		local ok, err = HatchService.hatch(userId, eggUid)
		if not ok then
			notify(player, tostring(err))
		end
	end)

	-- Hatch dari panel (jarak jauh): pemain harus berada dekat Coop sendiri.
	Net.on("HatchEgg", Check.args(Check.uid), function(player, eggUid)
		local userId = player.UserId
		local plot = PlotService.getPlot(userId)
		local root = Actors.getRoot(userId)
		if
			not (plot and root)
			or PlotService.distanceToPlot(plot, root.Position) > Eggs.hatchRemoteDistance
		then
			notify(player, "Too far away.")
			return
		end
		local ok, err = HatchService.hatch(userId, eggUid)
		if not ok then
			notify(player, tostring(err))
		end
	end)
end

return HatchService
