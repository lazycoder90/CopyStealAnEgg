--!nonstrict
-- PetService: inventaris pet, equip/unequip/Equip Best, lock, dan folder ActivePets di Coop
-- (klien yang merender pet dari atribut folder itu).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Creatures = require(Shared.Config.Creatures)
local PetMath = require(Shared.Logic.PetMath)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr = Types.Names, Types.Attr

local PetService = {}

function PetService.petIncome(pet): number
	return PetMath.petIncome(pet.id, pet.kg, pet.muts)
end

function PetService.equippedCount(data): number
	local n = 0
	for _, pet in data.pets do
		if pet.eq then
			n += 1
		end
	end
	return n
end

function PetService.petCount(data): number
	local n = 0
	for _ in data.pets do
		n += 1
	end
	return n
end

-- Membangun ulang folder ActivePets di Coop: hanya N pet aktif terbaik (visiblePets menurut level pen).
function PetService.refreshPlot(userId: number)
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	if not (data and plot) then
		return
	end
	local folder = plot:FindFirstChild(Names.PlotPets)
	if not folder then
		return
	end

	local active = {}
	for uid, pet in data.pets do
		if pet.eq then
			table.insert(active, { uid = uid, pet = pet, income = PetService.petIncome(pet) })
		end
	end
	table.sort(active, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)

	local visible = Progression.visiblePetsFor(data.penLevel)
	local desired = {}
	for i = 1, math.min(visible, #active) do
		desired[active[i].uid] = active[i]
	end

	for _, child in folder:GetChildren() do
		if not desired[child.Name] then
			child:Destroy()
		end
	end
	for uid, item in desired do
		if not folder:FindFirstChild(uid) then
			local creature = Creatures.get(item.pet.id)
			local f = Instance.new("Folder")
			f.Name = uid
			f:SetAttribute(Attr.PetUid, uid)
			f:SetAttribute(Attr.SpeciesId, item.pet.id)
			f:SetAttribute(Attr.Rarity, creature.rarity)
			f:SetAttribute(Attr.Kg, item.pet.kg)
			f:SetAttribute(Attr.Income, item.income)
			f:SetAttribute(Attr.Muts, table.concat(item.pet.muts, ","))
			f:SetAttribute(Attr.Gender, item.pet.g)
			f.Parent = folder
		end
	end
end

-- Menambah pet ke inventaris (kapasitas dicek pemanggil). Mengembalikan true.
function PetService.addPet(userId: number, petUid: string, pet): boolean
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	data.pets[petUid] = pet
	StateReplicator.set(userId, `pets.{petUid}`, pet)
	return true
end

function PetService.equip(userId: number, uid: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	local pet = data and data.pets[uid]
	if not pet then
		return false, "Pet not found."
	end
	if pet.eq then
		return true
	end
	if PetService.equippedCount(data) >= data.equipSlots then
		return false, "No free equip slots."
	end
	pet.eq = true
	StateReplicator.set(userId, `pets.{uid}.eq`, true)
	PetService.refreshPlot(userId)
	return true
end

function PetService.unequip(userId: number, uid: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	local pet = data and data.pets[uid]
	if not pet then
		return false, "Pet not found."
	end
	if pet.eq then
		pet.eq = false
		StateReplicator.set(userId, `pets.{uid}.eq`, false)
		PetService.refreshPlot(userId)
	end
	return true
end

-- Pasang pet berpendapatan tertinggi sebanyak slot yang ada.
function PetService.equipBest(userId: number): boolean
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	local list = {}
	for uid, pet in data.pets do
		table.insert(list, { uid = uid, pet = pet, income = PetService.petIncome(pet) })
	end
	table.sort(list, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	for i, item in list do
		local shouldEquip = i <= data.equipSlots
		if item.pet.eq ~= shouldEquip then
			item.pet.eq = shouldEquip
			StateReplicator.set(userId, `pets.{item.uid}.eq`, shouldEquip)
		end
	end
	PetService.refreshPlot(userId)
	return true
end

function PetService.setLock(userId: number, uid: string, locked: boolean): boolean
	local data = DataService.getByUserId(userId)
	local pet = data and data.pets[uid]
	if not pet then
		return false
	end
	pet.lock = locked
	StateReplicator.set(userId, `pets.{uid}.lock`, locked)
	return true
end

function PetService.Init()
	-- order 60: setelah PlotService (5) dan GrowthService (50) saat masuk.
	PlayerLifecycle.onJoin("PetService", 60, function(ctx)
		PetService.refreshPlot(ctx.userId)
	end)
	PlayerLifecycle.onLeaving("PetService", 60, function(ctx)
		local plot = PlotService.getPlot(ctx.userId)
		local folder = plot and plot:FindFirstChild(Names.PlotPets)
		if folder then
			folder:ClearAllChildren()
		end
	end)

	InvariantChecker.register("Pets", function(entry)
		local out = {}
		local equipped = PetService.equippedCount(entry.data)
		if equipped > entry.data.equipSlots then
			table.insert(out, `pet aktif {equipped} > slot {entry.data.equipSlots}`)
		end
		return out
	end)

	TestBridge.register("pets.list", function(userId)
		local data = DataService.getByUserId(userId)
		local out = {}
		for uid, pet in (data and data.pets) or {} do
			table.insert(out, {
				uid = uid,
				id = pet.id,
				eq = pet.eq,
				kg = pet.kg,
				income = PetService.petIncome(pet),
			})
		end
		return out
	end)
	TestBridge.register("pets.give", function(userId, speciesId, kg)
		local uid = string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
		PetService.addPet(userId, uid, {
			id = speciesId,
			kg = kg or 1,
			g = "M",
			muts = {},
			eq = false,
			lock = false,
			t = 0,
		})
		return uid
	end)
	TestBridge.register("pets.equip", PetService.equip)
	TestBridge.register("pets.unequip", PetService.unequip)
end

function PetService.Start()
	Net.on("EquipPet", Check.args(Check.uid), function(player, uid)
		local ok, err = PetService.equip(player.UserId, uid)
		if not ok and err then
			Net.fire("Notify", player, err, "error")
		end
	end)
	Net.on("UnequipPet", Check.args(Check.uid), function(player, uid)
		PetService.unequip(player.UserId, uid)
	end)
	Net.on("EquipBest", Check.args(), function(player)
		PetService.equipBest(player.UserId)
	end)
	Net.on("LockPet", Check.args(Check.uid, Check.bool), function(player, uid, locked)
		PetService.setLock(player.UserId, uid, locked)
	end)
end

return PetService
