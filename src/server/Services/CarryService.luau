--!nonstrict
-- CarryService: SATU-SATUNYA pemilik state "sedang membawa telur" (kunci userId).
-- Jenis carry bersifat pluggable (registerKind): "wild" (telur dari sarang) di sini; "steal" didaftarkan
-- StealService (Fase 3). impl kind:
--   describe(state) -> { eggUid, speciesId, name, rarity, kg, projectedIncome, stolen }
--   model(state)    -> Model yang ditempel ke kepala pembawa
--   drop(state, userId, reason, groundPos)   telur jatuh di tanah
--   returnHome(state, userId, reason)        telur kembali ke asalnya (nest / pemilik)
--   consume(state, userId) -> eggData        telur diserahkan untuk ditempatkan (data: uid,id,kg,muts,growTotal,progress,stolenFrom)
-- Telur yang dibawa hanya ada di memori (hilang saat crash = kembali ke nest). Lihat docs/CHANGES.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local PetMath = require(Shared.Logic.PetMath)
local ModelFactory = require(Shared.ModelFactory)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local GameEvents = require(Systems.GameEvents)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local EggSpawnService = require(script.Parent.EggSpawnService)

local Names = Types.Names

local CarryService = {}

local carries = {} -- [userId] = { kind, maid, visual = { model, weld }, ... }
local kinds = {}
local immunity = {} -- [userId] = os.clock() batas kebal pickup

function CarryService.registerKind(name: string, impl)
	kinds[name] = impl
end

local function notify(userId: number, message: string, kind: string?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("Notify", player, message, kind or "error")
	end
end
CarryService.notify = notify

local function sendChanged(userId: number, payload)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("CarryChanged", player, payload)
	end
end

-- Tempel model ke kepala (atau root bila tidak ada kepala), tak ter-anchor, ringan.
local function attachVisual(userId: number, model: Model)
	local character = Actors.getCharacter(userId)
	if not character then
		return nil
	end
	local anchorPart = character:FindFirstChild("Head") or Actors.getRoot(userId)
	if not anchorPart then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	local d = ModelFactory.eggDiameter(model:GetAttribute(Types.Attr.Kg) or 1)
	model.Parent = character
	model:PivotTo(anchorPart.CFrame * CFrame.new(0, anchorPart.Size.Y / 2 + d * 0.65, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	return { model = model, weld = weld }
end

local function detachVisual(state)
	local visual = state.visual
	if not visual then
		return
	end
	if visual.weld then
		visual.weld:Destroy()
	end
	if visual.model and visual.model.Parent then
		visual.model.Parent = workspace
		for _, d in visual.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.Massless = false
			end
		end
	end
	state.visual = nil
end

-- Titik tanah di depan/di bawah pembawa (raycast ke bawah), nil bila tak ada root.
local function groundPosition(userId: number, forward: boolean): Vector3?
	local root = Actors.getRoot(userId)
	local character = Actors.getCharacter(userId)
	if not (root and character) then
		return nil
	end
	local origin = root.Position + Vector3.new(0, 2, 0)
	if forward then
		origin += root.CFrame.LookVector * 4
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild(Names.WorldEggs) }
	local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0), params)
	if hit then
		return hit.Position
	end
	return Vector3.new(origin.X, 0, origin.Z)
end

-- ===== Jenis "wild": telur dari sarang =====
kinds.wild = {
	describe = function(state)
		local e = state.entity
		local creature = Creatures.get(e.speciesId)
		return {
			eggUid = e.uid,
			speciesId = e.speciesId,
			name = creature.name,
			rarity = e.rarity,
			kg = e.kg,
			projectedIncome = PetMath.eggProjectedIncome(e.speciesId, e.kg, e.muts),
			stolen = false,
		}
	end,
	model = function(state)
		return state.entity.model
	end,
	drop = function(state, _userId, _reason, groundPos)
		EggSpawnService.dropEggAt(state.entity, groundPos)
	end,
	returnHome = function(state)
		EggSpawnService.returnToNest(state.entity)
	end,
	consume = function(state)
		local e = state.entity
		local data = {
			uid = e.uid,
			id = e.speciesId,
			kg = e.kg,
			muts = e.muts,
			growTotal = e.growTotal,
			progress = 0,
			stolenFrom = nil,
		}
		EggSpawnService.destroyEntity(e)
		return data
	end,
}

function CarryService.get(userId: number)
	return carries[userId]
end

function CarryService.isCarrying(userId: number): boolean
	return carries[userId] ~= nil
end

function CarryService.setPickupImmunity(userId: number, seconds: number)
	immunity[userId] = os.clock() + seconds
end

-- Mulai membawa. state.kind wajib sudah terdaftar. Mengembalikan true bila berhasil.
function CarryService.start(userId: number, state): boolean
	local impl = kinds[state.kind]
	if not impl or carries[userId] then
		return false
	end
	local model = impl.model(state)
	local visual = attachVisual(userId, model)
	if not visual then
		return false
	end
	state.visual = visual
	state.maid = Maid.new()
	carries[userId] = state

	-- Mati atau karakter dihapus saat membawa -> telur jatuh (sebelum model ikut terhapus bersama karakter).
	local humanoid = Actors.getHumanoid(userId)
	if humanoid then
		state.maid:Give(humanoid.Died:Connect(function()
			CarryService.drop(userId, "died")
		end))
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		state.maid:Give(player.CharacterRemoving:Connect(function()
			CarryService.drop(userId, "died")
		end))
	end

	local payload = impl.describe(state)
	payload.state = "Carrying"
	sendChanged(userId, payload)
	return true
end

-- Menyelesaikan state sebelum memanggil impl (supaya error impl tidak meninggalkan state menggantung).
local function finish(userId: number, reason: string)
	local state = carries[userId]
	if not state then
		return nil
	end
	carries[userId] = nil
	if state.maid then
		state.maid:Clean()
	end
	sendChanged(userId, { state = "None", reason = reason, eggUid = nil })
	return state
end

-- Telur dijatuhkan di tanah (tombol Drop, mati, dipukul). Jika root hilang, telur dikembalikan.
function CarryService.drop(userId: number, reason: string): boolean
	local state = carries[userId]
	if not state then
		return false
	end
	local ground = groundPosition(userId, reason == "dropped")
	detachVisual(state)
	finish(userId, reason)
	local impl = kinds[state.kind]
	local ok, err
	if ground then
		ok, err = pcall(impl.drop, state, userId, reason, ground)
	else
		ok, err = pcall(impl.returnHome, state, userId, reason)
	end
	if not ok then
		warn("[CarryService] drop gagal:", err)
	end
	return true
end

-- Telur dikembalikan ke asalnya (tertangkap guardian, pemain keluar).
function CarryService.forceReturn(userId: number, reason: string): boolean
	local state = carries[userId]
	if not state then
		return false
	end
	detachVisual(state)
	finish(userId, reason)
	local ok, err = pcall(kinds[state.kind].returnHome, state, userId, reason)
	if not ok then
		warn("[CarryService] returnHome gagal:", err)
	end
	return true
end

-- Menyerahkan telur untuk ditempatkan. Mengembalikan eggData (lihat impl.consume) atau nil.
function CarryService.consume(userId: number)
	local state = carries[userId]
	if not state then
		return nil
	end
	detachVisual(state)
	finish(userId, "placed")
	local ok, result = pcall(kinds[state.kind].consume, state, userId)
	if not ok then
		warn("[CarryService] consume gagal:", result)
		return nil
	end
	return result
end

function CarryService.tryPickupWorld(userId: number, eggUid: string): (boolean, string?)
	if carries[userId] then
		return false, Eggs.messages.alreadyCarrying
	end
	if (immunity[userId] or 0) > os.clock() then
		return false, "You can't pick up an egg right now."
	end
	local humanoid = Actors.getHumanoid(userId)
	local root = Actors.getRoot(userId)
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false, "You can't pick up an egg right now."
	end
	local entity = EggSpawnService.getEntity(eggUid)
	if not entity then
		return false, "That egg is gone."
	end
	local distance = (root.Position - EggSpawnService.entityPosition(entity)).Magnitude
	if distance > Eggs.grabMaxDistance + Eggs.grabValidateSlack then
		return false, "Too far away."
	end
	local taken = EggSpawnService.takeEgg(eggUid)
	if not taken then
		return false, "That egg is not available."
	end
	local started = CarryService.start(userId, { kind = "wild", entity = taken })
	if not started then
		EggSpawnService.returnToNest(taken)
		return false, "Could not pick up the egg."
	end
	GameEvents.EggGrabbed:Fire({
		userId = userId,
		eggUid = taken.uid,
		speciesId = taken.speciesId,
		rarity = taken.rarity,
		zone = taken.zone,
		grand = taken.grand,
	})
	return true
end

function CarryService.Init()
	-- order 10: paling awal saat keluar, supaya telur kembali sebelum data/plot dibersihkan.
	PlayerLifecycle.onLeaving("CarryService", 10, function(ctx)
		CarryService.forceReturn(ctx.userId, "left")
		immunity[ctx.userId] = nil
	end)

	TestBridge.register("carry.pickup", function(userId, eggUid)
		local ok, err = CarryService.tryPickupWorld(userId, eggUid)
		return { ok = ok, err = err }
	end)
	TestBridge.register("carry.drop", function(userId, reason)
		return CarryService.drop(userId, reason or "dropped")
	end)
	TestBridge.register("carry.return", function(userId, reason)
		return CarryService.forceReturn(userId, reason or "returned")
	end)
	TestBridge.register("carry.get", function(userId)
		local state = carries[userId]
		if not state then
			return nil
		end
		return { kind = state.kind, eggUid = state.eggUid or (state.entity and state.entity.uid) }
	end)
end

function CarryService.Start()
	EggSpawnService.onGrabRequested:Connect(function(player, eggUid)
		local ok, err = CarryService.tryPickupWorld(player.UserId, eggUid)
		if not ok and err then
			notify(player.UserId, err, "error")
		end
	end)

	Net.on("DropEgg", Check.args(), function(player)
		CarryService.drop(player.UserId, "dropped")
	end)
end

return CarryService
