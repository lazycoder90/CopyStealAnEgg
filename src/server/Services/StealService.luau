--!nonstrict
-- StealService: mencuri telur placed dari Coop pemain lain (docs/CHANGES.md #1).
-- Telur TETAP di profil korban (dibekukan lewat GrowthService.setFrozen, modelnya dihapus) sampai pencuri
-- berhasil menaruhnya di Coop sendiri (consume = transfer atomik). Kalau batal (jatuh lalu kembali,
-- pencuri/korban keluar), telur cukup dilepas dari status beku: tidak ada yang hilang.
--
-- Satu "record" per pencurian (kunci "victimId:eggUid"), bertahan selama carry/drop:
--   { key, victimId, eggUid, speciesId, kg, muts, model, stage = "carried" | "dropped", thiefId?,
--     droppedAt?, returnAt?, done, cancelled }
-- Waktu pengembalian telur jatuh memakai waktu NYATA (os.clock).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Zones = require(Shared.Config.Zones)
local PetMath = require(Shared.Logic.PetMath)
local ModelFactory = require(Shared.ModelFactory)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags

local StealService = {}

local STEAL_MAX_DISTANCE = 14 -- stud dari pencuri ke telur
local PROMPT_DISTANCE = 12
local ALERT_SECONDS = 8
local ORPHAN_SECONDS = 40
local DROP_PREFIX = "StolenEgg_"

local records = {} -- [key] = record
local alertTokens = {} -- [victimId] = number

local function keyOf(victimId: number, eggUid: string): string
	return `{victimId}:{eggUid}`
end

local function effectsFolder(): Instance
	local folder = workspace:FindFirstChild(Names.Effects)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Names.Effects
		folder.Parent = workspace
	end
	return folder
end

local function destroyModel(rec)
	if rec.model then
		rec.model:Destroy()
		rec.model = nil
	end
end

-- Mengakhiri record (idempoten). Mengembalikan true hanya pada panggilan pertama.
local function finish(rec): boolean
	if rec.done then
		return false
	end
	rec.done = true
	if records[rec.key] == rec then
		records[rec.key] = nil
	end
	destroyModel(rec)
	return true
end

-- Telur kembali ke korban: lepas dari status beku dan bangun ulang modelnya (idempoten).
local function returnToVictim(rec)
	if not finish(rec) then
		return
	end
	GrowthService.setFrozen(rec.victimId, rec.eggUid, false)
	if rec.cancelled then
		return -- korban sedang keluar: profilnya dilepas sebentar lagi
	end
	local data = DataService.getByUserId(rec.victimId)
	if data and data.eggs[rec.eggUid] then
		GrowthService.ensureModel(rec.victimId, rec.eggUid)
	end
end

local function buildModel(rec)
	local creature = Creatures.get(rec.speciesId)
	local zone = Zones.get(creature.zone)
	local accent = Color3.fromRGB(zone.accentRgb[1], zone.accentRgb[2], zone.accentRgb[3])
	local model = ModelFactory.makeEgg(creature, rec.kg, accent)
	model.Name = DROP_PREFIX .. rec.eggUid
	model:SetAttribute(Attr.EggUid, rec.eggUid)
	model:SetAttribute(Attr.SpeciesId, rec.speciesId)
	model:SetAttribute(Attr.Rarity, creature.rarity)
	model:SetAttribute(Attr.Kg, rec.kg)
	model:SetAttribute(Attr.Income, PetMath.eggProjectedIncome(rec.speciesId, rec.kg, rec.muts))
	model:SetAttribute(Attr.ZoneIndex, creature.zone)
	model:SetAttribute(Attr.Carried, true)
	return model
end

local function newState(rec)
	return {
		kind = "steal",
		victimId = rec.victimId,
		eggUid = rec.eggUid,
		speciesId = rec.speciesId,
		kg = rec.kg,
		muts = rec.muts,
		model = rec.model,
		record = rec,
	}
end

local function tutorialActive(userId: number): boolean
	local module = script.Parent:FindFirstChild("TutorialService")
	if not module then
		return false
	end
	local ok, service = pcall(require, module)
	if not ok or type(service) ~= "table" or type(service.isActive) ~= "function" then
		return false
	end
	local okCall, active = pcall(service.isActive, userId)
	return okCall and active == true
end

local function raiseAlert(victimId: number, thiefId: number, rec)
	local plot = PlotService.getPlot(victimId)
	if plot then
		plot:SetAttribute(Attr.StealAlert, true)
		local token = (alertTokens[victimId] or 0) + 1
		alertTokens[victimId] = token
		task.delay(ALERT_SECONDS, function()
			if alertTokens[victimId] ~= token then
				return
			end
			local current = PlotService.getPlot(victimId)
			if current then
				current:SetAttribute(Attr.StealAlert, false)
			end
		end)
	end
	local player = Players:GetPlayerByUserId(victimId)
	if player then
		local creature = Creatures.get(rec.speciesId)
		Net.fire("StealAlert", player, {
			thiefUserId = thiefId,
			thiefName = Actors.getName(thiefId),
			eggUid = rec.eggUid,
			speciesId = rec.speciesId,
			name = creature.name,
		})
	end
end

-- Mengembalikan true, atau false + pesan galat (juga dikirim ke pencuri).
function StealService.trySteal(
	thiefId: number,
	victimId: number,
	eggUid: string
): (boolean, string?)
	local function fail(message: string)
		CarryService.notify(thiefId, message, "error")
		return false, message
	end

	if thiefId == victimId then
		return fail("You can't steal your own egg!")
	end
	local thiefData = DataService.getByUserId(thiefId)
	local victimData = DataService.getByUserId(victimId)
	if not (thiefData and victimData) then
		return fail("That egg is not available.")
	end
	if thiefData.tutorial.done == false or tutorialActive(thiefId) then
		return fail("Finish the tutorial before stealing!")
	end
	if CarryService.isCarrying(thiefId) then
		return fail(Eggs.messages.alreadyCarrying)
	end
	local root = Actors.getRoot(thiefId)
	local humanoid = Actors.getHumanoid(thiefId)
	if not (root and humanoid) or humanoid.Health <= 0 then
		return fail("You can't steal right now.")
	end

	local egg = victimData.eggs[eggUid]
	if not egg or egg.loc ~= "placed" or GrowthService.isFrozen(victimId, eggUid) then
		return fail("That egg is gone.")
	end
	local model = GrowthService.getModel(victimId, eggUid)
	if not model then
		return fail("That egg is gone.")
	end
	if (root.Position - model:GetPivot().Position).Magnitude > STEAL_MAX_DISTANCE then
		return fail("Get closer to steal the egg!")
	end

	local plot = PlotService.getPlot(victimId)
	if plot and (plot:GetAttribute(Attr.ShieldUntil) or 0) > Clock.now() then
		return fail("This Coop is protected by a Shell Shield!")
	end
	if (victimData.newbieProtectUntil or 0) > Clock.now() then
		return fail("This player is protected right now.")
	end

	local creature = Creatures.get(egg.id)
	local rec = {
		key = keyOf(victimId, eggUid),
		victimId = victimId,
		eggUid = eggUid,
		speciesId = egg.id,
		kg = egg.kg,
		muts = table.clone(egg.muts or {}),
		stage = "carried",
		thiefId = thiefId,
		done = false,
		cancelled = false,
	}
	rec.model = buildModel(rec)
	records[rec.key] = rec
	if not CarryService.start(thiefId, newState(rec)) then
		finish(rec)
		return fail("Could not steal the egg.")
	end

	-- Telur dibekukan di profil korban; modelnya di Coop hilang (pencuri membawa salinannya).
	GrowthService.setFrozen(victimId, eggUid, true)
	GrowthService.removeModel(victimId, eggUid)

	-- Pencuri melepas proteksi newbie miliknya sendiri (tidak adil mencuri sambil kebal).
	thiefData = DataService.getByUserId(thiefId)
	if thiefData and (thiefData.newbieProtectUntil or 0) > 0 then
		thiefData.newbieProtectUntil = 0
		StateReplicator.set(thiefId, "newbieProtectUntil", 0)
	end

	victimData.stats.beenStolen = (victimData.stats.beenStolen or 0) + 1
	StateReplicator.set(victimId, "stats.beenStolen", victimData.stats.beenStolen)

	CarryService.notify(thiefId, "You stole an EGG!", "success")
	raiseAlert(victimId, thiefId, rec)
	GameEvents.EggStolen:Fire({
		thiefId = thiefId,
		victimId = victimId,
		eggUid = eggUid,
		speciesId = egg.id,
		rarity = creature.rarity,
	})
	return true
end

-- Letakkan telur curian di tanah: siapa pun boleh mengambilnya lagi lewat GrabPrompt.
local function placeDrop(rec, groundPos: Vector3)
	local model = rec.model
	if not model then
		returnToVictim(rec)
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.Massless = false
		end
	end
	model:SetAttribute(Attr.Carried, false)
	model.Parent = effectsFolder()
	local d = ModelFactory.eggDiameter(rec.kg)
	model:PivotTo(CFrame.new(groundPos + Vector3.new(0, d * 0.625, 0)))

	local primary = model.PrimaryPart
	local prompt = primary:FindFirstChild(Names.GrabPrompt)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = Names.GrabPrompt
		prompt.ActionText = "Grab"
		prompt.ObjectText = Creatures.get(rec.speciesId).name .. " Egg (stolen)"
		prompt.HoldDuration = Eggs.grabHoldDuration
		prompt.MaxActivationDistance = Eggs.grabMaxDistance
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = primary
		prompt.Triggered:Connect(function(player)
			local ok, err = StealService.recover(player.UserId, rec.victimId, rec.eggUid)
			if not ok and err then
				CarryService.notify(player.UserId, err, "error")
			end
		end)
	end
	prompt.Enabled = true

	rec.stage = "dropped"
	rec.thiefId = nil
	rec.droppedAt = os.clock()
	rec.returnAt = rec.droppedAt + Eggs.stolenEggReturnTime
end

-- Mengambil telur curian yang jatuh. Korban: telur kembali ke Coop. Lainnya: lanjut membawa.
-- force = true melewati cek jarak/hidup (dipakai uji dan bot).
function StealService.recover(
	userId: number,
	victimId: number,
	eggUid: string,
	force: boolean?
): (boolean, string?)
	local rec = records[keyOf(victimId, eggUid)]
	if not rec or rec.stage ~= "dropped" or not rec.model then
		return false, "That egg is gone."
	end
	if not force then
		local root = Actors.getRoot(userId)
		local humanoid = Actors.getHumanoid(userId)
		if not (root and humanoid) or humanoid.Health <= 0 then
			return false, "You can't pick up an egg right now."
		end
		local distance = (root.Position - rec.model:GetPivot().Position).Magnitude
		if distance > Eggs.grabMaxDistance + Eggs.grabValidateSlack then
			return false, "Too far away."
		end
	end

	if userId ~= victimId and not force and CarryService.hasPickupImmunity(userId) then
		return false, "You can't pick up an egg right now."
	end

	if userId == victimId then
		returnToVictim(rec)
		CarryService.notify(userId, "Egg recovered!", "success")
		return true
	end

	if CarryService.isCarrying(userId) then
		return false, Eggs.messages.alreadyCarrying
	end
	local model = rec.model
	model:SetAttribute(Attr.Carried, true)
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild(Names.GrabPrompt)
	if prompt then
		prompt.Enabled = false
	end
	if not CarryService.start(userId, newState(rec)) then
		model:SetAttribute(Attr.Carried, false)
		if prompt then
			prompt.Enabled = true
		end
		return false, "Could not pick up the egg."
	end
	rec.stage = "carried"
	rec.thiefId = userId
	rec.returnAt = nil
	return true
end

function StealService.activeCount(): number
	local n = 0
	for _ in records do
		n += 1
	end
	return n
end

-- Uji: record aktif milik korban+uid (atau nil).
function StealService.getRecord(victimId: number, eggUid: string)
	return records[keyOf(victimId, eggUid)]
end

-- Prompt "Steal" di model telur placed (server). Pemilik dibaca dari plot induk model.
local function attachStealPrompt(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local primary = model.PrimaryPart
	if not primary or primary:FindFirstChild(Names.StealPrompt) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Names.StealPrompt
	prompt.ActionText = "Steal"
	local creature = Creatures.byId[model:GetAttribute(Attr.SpeciesId)]
	prompt.ObjectText = if creature then creature.name .. " Egg" else "Egg"
	prompt.HoldDuration = 1.0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = primary
	prompt.Triggered:Connect(function(player)
		local uid = model:GetAttribute(Attr.EggUid)
		local eggs = model.Parent
		local plot = eggs and eggs.Parent
		local owner = plot and plot:GetAttribute(Attr.OwnerUserId) or 0
		if not uid or owner == 0 or owner == player.UserId then
			return
		end
		StealService.trySteal(player.UserId, owner, uid)
	end)
end

local function onLeaving(ctx)
	local userId = ctx.userId

	-- Sebagai korban: pencuri yang membawa telurnya dibatalkan, telur jatuhnya dihapus.
	local mine = {}
	for _, rec in records do
		if rec.victimId == userId or rec.thiefId == userId then
			table.insert(mine, rec)
		end
	end
	for _, rec in mine do
		if rec.victimId == userId then
			rec.cancelled = true
			local thiefId = rec.thiefId
			local state = thiefId and CarryService.get(thiefId)
			if state and state.record == rec then
				CarryService.notify(thiefId, "Owner left", "info")
				CarryService.forceReturn(thiefId, "returned")
			end
		end
		returnToVictim(rec) -- idempoten
	end

	local plot = PlotService.getPlot(userId)
	if plot then
		plot:SetAttribute(Attr.StealAlert, false)
	end
	alertTokens[userId] = nil
end

function StealService.Init()
	CarryService.registerKind("steal", {
		describe = function(state)
			local creature = Creatures.get(state.speciesId)
			return {
				eggUid = state.eggUid,
				speciesId = state.speciesId,
				name = creature.name,
				rarity = creature.rarity,
				kg = state.kg,
				projectedIncome = PetMath.eggProjectedIncome(state.speciesId, state.kg, state.muts),
				stolen = true,
			}
		end,
		model = function(state)
			return state.model
		end,
		drop = function(state, _userId, _reason, groundPos)
			local rec = state.record
			if rec and not rec.done then
				placeDrop(rec, groundPos)
			end
		end,
		returnHome = function(state)
			if state.record then
				returnToVictim(state.record)
			end
		end,
		consume = function(state)
			local rec = state.record
			if not rec or rec.done then
				return nil
			end
			local data = DataService.getByUserId(rec.victimId)
			local egg = data and data.eggs[rec.eggUid]
			if not egg then
				finish(rec)
				GrowthService.setFrozen(rec.victimId, rec.eggUid, false)
				return nil
			end
			local eggData = {
				uid = rec.eggUid,
				id = egg.id,
				kg = egg.kg,
				muts = table.clone(egg.muts or {}),
				growTotal = egg.growTotal,
				progress = egg.progress,
				stolenFrom = rec.victimId,
			}
			data.eggs[rec.eggUid] = nil
			StateReplicator.set(rec.victimId, `eggs.{rec.eggUid}`, nil)
			finish(rec)
			GrowthService.setFrozen(rec.victimId, rec.eggUid, false)
			return eggData
		end,
	})

	-- order 20: sesudah Carry (10) mengembalikan telur pembawa, sebelum Growth (50) membersihkan model.
	PlayerLifecycle.onLeaving("StealService", 20, onLeaving)

	InvariantChecker.registerWorld("Steal", function()
		local out = {}
		local now = os.clock()
		local known = {}
		for key, rec in records do
			known[rec.model or rec] = true
			if not DataService.getByUserId(rec.victimId) then
				table.insert(out, `record {key}: korban tidak ada`)
			end
			if rec.stage == "carried" then
				local state = rec.thiefId and CarryService.get(rec.thiefId)
				if not (state and state.record == rec) then
					table.insert(out, `record {key}: carried tanpa pembawa`)
				end
			elseif not (rec.model and rec.model.Parent) then
				table.insert(out, `record {key}: dropped tanpa model`)
			elseif now - (rec.droppedAt or now) > ORPHAN_SECONDS then
				table.insert(out, `record {key}: telur curian jatuh > {ORPHAN_SECONDS} detik`)
			end
		end
		for _, entry in DataService.all() do
			for uid in entry.data.eggs do
				if
					GrowthService.isFrozen(entry.userId, uid)
					and not records[keyOf(entry.userId, uid)]
				then
					table.insert(out, `telur beku tanpa record: {entry.userId}:{uid}`)
				end
			end
		end
		for _, child in effectsFolder():GetChildren() do
			if string.sub(child.Name, 1, #DROP_PREFIX) == DROP_PREFIX and not known[child] then
				table.insert(out, `model curian yatim: {child.Name}`)
			end
		end
		return out
	end)

	TestBridge.register("steal.try", function(thiefId, victimId, eggUid)
		local ok, err = StealService.trySteal(thiefId, victimId, eggUid)
		return { ok = ok, err = err }
	end)
	TestBridge.register("steal.recover", function(userId, victimId, eggUid)
		local ok, err = StealService.recover(userId, victimId, eggUid, true)
		return { ok = ok, err = err }
	end)
	TestBridge.register("steal.stats", function()
		local carried, dropped = 0, 0
		for _, rec in records do
			if rec.stage == "carried" then
				carried += 1
			else
				dropped += 1
			end
		end
		return { carried = carried, dropped = dropped }
	end)
end

function StealService.Start()
	for _, model in CollectionService:GetTagged(Tags.PlacedEgg) do
		attachStealPrompt(model)
	end
	CollectionService:GetInstanceAddedSignal(Tags.PlacedEgg):Connect(attachStealPrompt)

	-- Telur curian yang jatuh kembali ke korban setelah Eggs.stolenEggReturnTime (waktu nyata).
	Clock.every10Hz(function()
		local now = os.clock()
		local due = {}
		for _, rec in records do
			if rec.stage == "dropped" and rec.returnAt and now >= rec.returnAt then
				table.insert(due, rec)
			end
		end
		for _, rec in due do
			CarryService.notify(rec.victimId, "Your stolen egg returned home.", "info")
			returnToVictim(rec)
		end
	end)

	-- Pencuri berhasil menaruh telur: stats.stolen dihitung sekali per penempatan.
	GameEvents.EggPlaced:Connect(function(event)
		if not event.stolen then
			return
		end
		local data = DataService.getByUserId(event.userId)
		if data then
			data.stats.stolen = (data.stats.stolen or 0) + 1
			StateReplicator.set(event.userId, "stats.stolen", data.stats.stolen)
		end
	end)
end

return StealService
