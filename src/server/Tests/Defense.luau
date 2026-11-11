--!nonstrict
-- Skenario uji PvP: Frying Pan, Sticky Yolk Trap, Shell Shield (bot sebagai pembawa/pemilik). Lambat (~45 detik).
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Defense")

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Config.Layout)
local PvpRules = require(Shared.Logic.PvpRules)
local Types = require(Shared.Types)

local Actors = require(Server.Systems.Actors)
local Bots = require(Server.Systems.Bots)
local Clock = require(Server.Systems.Clock)
local GameEvents = require(Server.Systems.GameEvents)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local AntiExploit = require(Server.Services.AntiExploit)
local CarryService = require(Server.Services.CarryService)
local CurrencyService = require(Server.Services.CurrencyService)
local DataService = require(Server.Services.DataService)
local DefenseService = require(Server.Services.DefenseService)
local GrowthService = require(Server.Services.GrowthService)
local PlotService = require(Server.Services.PlotService)
local StealService = require(Server.Services.StealService)

local Attr, Tags = Types.Attr, Types.Tags

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local OWNER = -3 -- pemilik telur (korban) dan pemilik trap bot
	local CARRIER = -1 -- bot pembawa / sasaran Pan
	local PLAIN = -2 -- bot tanpa telur
	local SPECIES = "moss_pup"

	local function teleport(pos: Vector3, lookAt: Vector3?)
		AntiExploit.grace(userId, 5, "test")
		local root = Actors.getRoot(userId)
		root.CFrame = if lookAt
			then CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
			else CFrame.new(pos)
		root.AssemblyLinearVelocity = Vector3.zero
		T.wait(0.15)
	end
	local function prepBot(id: number)
		local data = DataService.getByUserId(id)
		data.tutorial.done = true
		data.newbieProtectUntil = 0
		return data
	end
	local function prepPlayer()
		local data = DataService.getByUserId(userId)
		data.tutorial.done = true
		data.newbieProtectUntil = 0
		return data
	end
	local function victimEgg(): string
		local vd = DataService.getByUserId(OWNER)
		for uid, egg in vd.eggs do
			if
				egg.loc == "placed"
				and not GrowthService.isFrozen(OWNER, uid)
				and GrowthService.getModel(OWNER, uid)
			then
				return uid
			end
		end
		return Bots.giveEgg(OWNER, SPECIES, nil, false)
	end
	-- Bot membawa telur curian dari OWNER.
	local function makeCarrier(botId: number): boolean
		if CarryService.isCarrying(botId) then
			return true
		end
		local uid = victimEgg()
		local pos = GrowthService.getModel(OWNER, uid):GetPivot().Position
		Bots.moveTo(botId, pos.X + 3, 3, pos.Z)
		return StealService.trySteal(botId, OWNER, uid)
	end
	local function findDome(ownerId: number)
		for _, inst in CollectionService:GetTagged(Tags.Shield) do
			if inst:GetAttribute(Attr.OwnerUserId) == ownerId then
				return inst
			end
		end
		return nil
	end
	local function trapParts(ownerId: number): number
		local n = 0
		for _, inst in CollectionService:GetTagged(Tags.Trap) do
			if inst:GetAttribute(Attr.TrapOwner) == ownerId then
				n += 1
			end
		end
		return n
	end

	Bots.removeAll()
	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik
	local data = prepPlayer()
	local plot = PlotService.getPlot(userId)
	local floorPos = PlotService.getFloor(plot).Position

	-- ===== Tool Pan =====
	local function countPans(): number
		local n = 0
		for _, container in { Actors.getPlayer(userId).Backpack, Actors.getCharacter(userId) } do
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child.Name == PvpRules.panToolName then
					n += 1
				end
			end
		end
		return n
	end
	T.wait(0.3)
	T.check("tepat satu Frying Pan", countPans() == 1, countPans())
	local pan = Actors.getPlayer(userId).Backpack:FindFirstChild(PvpRules.panToolName)
	T.check(
		"Pan: Handle, tidak bisa di-drop",
		pan ~= nil and pan:FindFirstChild("Handle") ~= nil and pan.CanBeDropped == false
	)

	-- ===== Persiapan bot =====
	Bots.spawn(OWNER)
	prepBot(OWNER)
	for _ = 1, 3 do
		Bots.giveEgg(OWNER, SPECIES, nil, false)
	end
	Bots.spawn(CARRIER)
	prepBot(CARRIER)
	Bots.spawn(PLAIN)
	prepBot(PLAIN)
	T.wait(0.2)

	-- ===== Pan =====
	local swingPos = Vector3.new(floorPos.X, 3, floorPos.Z)
	local function standAndFace()
		teleport(swingPos, swingPos + Vector3.new(0, 0, 10)) -- menghadap +Z
	end
	local function place(botId: number, dx: number, dz: number)
		Bots.moveTo(botId, swingPos.X + dx, 3, swingPos.Z + dz)
	end
	standAndFace()
	local bonks0 = data.stats.bonks or 0
	local baseWalk = Actors.getHumanoid(PLAIN).WalkSpeed -- kecepatan dasar bot (diatur SpeedService)

	place(PLAIN, 0, 5)
	DefenseService.resetSwingCooldown(userId)
	local okSwing, hits = DefenseService.swing(userId)
	T.check("ayunan tanpa carrier: tidak ada korban", okSwing == true and hits == 0, hits)
	T.check(
		"non-carrier tidak kena stun/knockback",
		not DefenseService.isStunned(PLAIN) and Actors.getHumanoid(PLAIN).WalkSpeed == baseWalk
	)

	local carrying = makeCarrier(CARRIER)
	T.check("bot membawa telur curian", carrying == true and CarryService.isCarrying(CARRIER))
	local uid = CarryService.get(CARRIER).eggUid

	-- Di luar kerucut/jarak: tidak kena.
	for _, case in
		{
			{ "di belakang", 0, -5 },
			{ "di samping 90 derajat", 6, 0 },
			{ "di luar jarak", 0, 15 },
		}
	do
		place(CARRIER, case[2], case[3])
		DefenseService.resetSwingCooldown(userId)
		local _, h = DefenseService.swing(userId)
		T.check(`Pan meleset: {case[1]}`, h == 0 and CarryService.isCarrying(CARRIER), h)
	end

	-- Kena: di dalam kerucut dan jarak.
	local bonkedEvent
	local connection = GameEvents.Bonked:Connect(function(e)
		bonkedEvent = e
	end)
	place(CARRIER, 3, 7)
	DefenseService.resetSwingCooldown(userId)
	okSwing, hits = DefenseService.swing(userId)
	connection.Disconnect()
	T.check("Pan kena carrier", okSwing == true and hits == 1, hits)
	T.check("telur dijatuhkan", not CarryService.isCarrying(CARRIER))
	local rec = StealService.getRecord(OWNER, uid)
	T.check("telur curian jatuh ke tanah", rec ~= nil and rec.stage == "dropped")
	T.check(
		"carrier di-stun (WalkSpeed 0)",
		DefenseService.isStunned(CARRIER) and Actors.getHumanoid(CARRIER).WalkSpeed == 0
	)
	T.check("AntiExploit grace untuk korban", AntiExploit.inGrace(CARRIER))
	T.check("stats.bonks +1", data.stats.bonks == bonks0 + 1, data.stats.bonks)
	T.check(
		"event Bonked",
		bonkedEvent ~= nil and bonkedEvent.userId == CARRIER and bonkedEvent.byUserId == userId
	)
	local again, reason = DefenseService.swing(userId)
	T.check(
		"cooldown 1.2 detik menolak ayunan berikutnya",
		again == false and reason == "cooldown",
		reason
	)
	T.wait(0.7)
	T.check(
		"stun berakhir dan WalkSpeed pulih",
		not DefenseService.isStunned(CARRIER) and Actors.getHumanoid(CARRIER).WalkSpeed == baseWalk
	)
	StealService.recover(OWNER, OWNER, uid, true) -- korban mengambil kembali

	-- Spawn pad bebas PvP.
	local pad = Layout.spawnPad
	makeCarrier(CARRIER)
	teleport(Vector3.new(pad.x, 3, pad.z), Vector3.new(pad.x, 3, pad.z + 10))
	Bots.moveTo(CARRIER, pad.x, 3, pad.z + 5)
	DefenseService.resetSwingCooldown(userId)
	okSwing, reason = DefenseService.swing(userId)
	T.check(
		"Pan tidak berfungsi di spawn pad (penyerang)",
		okSwing == false and CarryService.isCarrying(CARRIER),
		reason
	)
	teleport(Vector3.new(pad.x, 3, pad.z - pad.radius - 4), Vector3.new(pad.x, 3, pad.z)) -- di luar pad
	Bots.moveTo(CARRIER, pad.x, 3, pad.z - pad.radius + 3) -- 7 stud di depan, masih di dalam pad
	DefenseService.resetSwingCooldown(userId)
	_, hits = DefenseService.swing(userId)
	T.check(
		"Pan tidak mengenai korban di spawn pad",
		hits == 0 and CarryService.isCarrying(CARRIER),
		hits
	)

	-- ===== Trap (pemilik = pemain uji) =====
	standAndFace()
	data = prepPlayer()
	data.lastIncomePerSec = 0
	T.check("harga trap minimal 10K", DefenseService.trapCost(userId) == 10000)
	data.lastIncomePerSec = 1e6
	T.check("harga trap = 2 menit income", DefenseService.trapCost(userId) == 1.2e8)
	data.lastIncomePerSec = 0

	CurrencyService.set(userId, "cash", 0)
	local trapPos = swingPos + Vector3.new(8, -3, 0)
	T.check("trap tanpa uang ditolak", DefenseService.placeTrap(userId, trapPos) == false)
	CurrencyService.set(userId, "cash", 1e6)
	local _, padErr = DefenseService.placeTrap(userId, Vector3.new(pad.x, 0, pad.z))
	T.check(
		"trap di spawn pad ditolak",
		padErr ~= nil and string.find(padErr, "spawn pad") ~= nil,
		padErr
	)
	T.check(
		"trap jauh dari Coop ditolak",
		DefenseService.placeTrap(userId, swingPos + Vector3.new(120, -3, 0)) == false
	)
	local _, farErr = DefenseService.placeTrap(userId, swingPos + Vector3.new(65, -3, 0))
	T.check(
		"trap jauh dari pemilik ditolak",
		farErr ~= nil and string.find(farErr, "too far") ~= nil,
		farErr
	)
	T.check("tidak ada uang terpotong oleh penolakan", data.cash == 1e6, data.cash)

	local okTrap, trapErr = DefenseService.placeTrap(userId, trapPos)
	T.check("trap valid terpasang", okTrap == true, trapErr)
	T.check("biaya 10K terpotong", math.abs(data.cash - (1e6 - 10000)) < 1e-6, data.cash)
	T.check(
		"Part trap bertag dengan TrapOwner",
		trapParts(userId) == 1 and DefenseService.activeTrapCount(userId) == 1
	)
	T.check(
		"trap kedua ditolak di pen < 6",
		DefenseService.placeTrap(userId, swingPos + Vector3.new(-8, -3, 0)) == false
	)
	data.penLevel = 6
	T.check(
		"trap kedua boleh di pen 6",
		DefenseService.placeTrap(userId, swingPos + Vector3.new(-8, -3, 0)) == true
	)
	T.check(
		"trap ketiga ditolak (maks 2)",
		DefenseService.placeTrap(userId, swingPos + Vector3.new(0, -3, 12)) == false
	)
	data.penLevel = 1

	-- Carrier non-pemilik melewati trap: terjebak lalu trap habis.
	makeCarrier(CARRIER)
	Bots.moveTo(CARRIER, swingPos.X + 8 + 2, 3, swingPos.Z)
	T.wait(0.4)
	T.check("carrier terjebak trap", DefenseService.isTrapped(CARRIER))
	T.check(
		"trap dipakai habis",
		trapParts(userId) == 1 and DefenseService.activeTrapCount(userId) == 1
	)
	Bots.remove(CARRIER) -- keluar saat terjebak: semua dilepas
	T.check(
		"keluar saat terjebak melepas anchor dan record",
		not DefenseService.isTrapped(CARRIER) and DefenseService.stats().trapped == 0
	)
	T.check("telur curian kembali ke korban", StealService.activeCount() == 0)

	-- Non-carrier tidak memicu trap.
	Bots.moveTo(PLAIN, swingPos.X - 8 + 1, 3, swingPos.Z)
	T.wait(0.4)
	T.check(
		"non-carrier tidak memicu trap",
		not DefenseService.isTrapped(PLAIN) and DefenseService.activeTrapCount(userId) == 1
	)

	-- ===== Trap bot menjebak pemain uji (anchor 7 detik) =====
	local victimPlot = PlotService.getPlot(OWNER)
	local botTrapPos = PlotService.localToWorld(victimPlot, 8, 16)
	local trapOk, botTrapErr = DefenseService.placeTrap(OWNER, botTrapPos, true)
	T.check("bot memasang trap di Coop-nya", trapOk == true, botTrapErr)
	local eggUid = victimEgg()
	local eggPos = GrowthService.getModel(OWNER, eggUid):GetPivot().Position
	teleport(eggPos + Vector3.new(4, 3, 0))
	local stolen = StealService.trySteal(userId, OWNER, eggUid)
	T.check("pemain uji mencuri untuk membawa telur", stolen == true)
	teleport(botTrapPos + Vector3.new(1.5, 3, 0))
	T.wait(0.4)
	local root = Actors.getRoot(userId)
	T.check(
		"pemain terjebak dan HRP di-anchor",
		DefenseService.isTrapped(userId) and root.Anchored == true
	)
	T.check("trap bot habis terpakai", DefenseService.activeTrapCount(OWNER) == 0)
	T.wait(7.2)
	root = Actors.getRoot(userId)
	T.check(
		"HRP dilepas setelah 7 detik",
		not DefenseService.isTrapped(userId) and root.Anchored == false
	)
	T.check("telur tetap dibawa", CarryService.isCarrying(userId))

	-- Mati saat terjebak: anchor/record dilepas, respawn normal.
	DefenseService.placeTrap(OWNER, botTrapPos, true)
	teleport(botTrapPos + Vector3.new(1.5, 3, 0))
	T.wait(0.4)
	T.check("terjebak lagi", DefenseService.isTrapped(userId))
	local oldCharacter = Actors.getCharacter(userId)
	Actors.getHumanoid(userId).Health = 0
	T.wait(0.6)
	T.check("mati: record trap dilepas", not DefenseService.isTrapped(userId))
	for _ = 1, 100 do
		local c = Actors.getCharacter(userId)
		if c and c ~= oldCharacter and c:FindFirstChild("HumanoidRootPart") then
			break
		end
		T.wait(0.1)
	end
	T.wait(1.2)
	T.check("telur curian yang dijatuhkan masih tercatat", StealService.activeCount() <= 1)
	StealService.recover(OWNER, OWNER, eggUid, true)
	T.check("Pan diberikan lagi setelah respawn (satu)", countPans() == 1, countPans())
	standAndFace()

	-- ===== Shield (pemilik = pemain uji) =====
	data = prepPlayer()
	data.penLevel = 1
	data.shieldReadyAt = 0
	local shieldOk, shieldErr = DefenseService.activateShield(userId)
	T.check("Shield aktif", shieldOk == true, shieldErr)
	local now = Clock.now()
	T.check(
		"shieldReadyAt = sekarang + 600",
		math.abs(data.shieldReadyAt - (now + 600)) <= 2,
		data.shieldReadyAt - now
	)
	local untilAt = plot:GetAttribute(Attr.ShieldUntil)
	T.check("ShieldUntil = sekarang + 60", math.abs(untilAt - (now + 60)) <= 2, untilAt - now)
	local remaining = DefenseService.getShieldRemaining(userId)
	T.check("getShieldRemaining ~60", remaining > 57 and remaining <= 60, remaining)
	local dome = findDome(userId)
	T.check(
		"kubah Ball bertag Shield tanpa tabrakan",
		dome ~= nil and dome.Shape == Enum.PartType.Ball and dome.CanCollide == false
	)
	T.check("Shield tidak bisa diaktifkan dua kali", DefenseService.activateShield(userId) == false)

	-- Dorong keluar non-pemilik.
	local half = Layout.plotSize / 2
	Bots.moveTo(PLAIN, floorPos.X + 10, 3, floorPos.Z + 10)
	T.wait(0.6)
	local botRoot = Actors.getRoot(PLAIN)
	local lx, lz = PlotService.worldToLocal(plot, botRoot.Position)
	T.check(
		"non-pemilik didorong keluar plot",
		not PvpRules.insideSquare(lx, lz, half),
		`{lx}, {lz}`
	)
	T.check("grace diberikan saat didorong", AntiExploit.inGrace(PLAIN))
	local ownerRoot = Actors.getRoot(userId)
	local ox, oz = PlotService.worldToLocal(plot, ownerRoot.Position)
	T.check("pemilik tidak didorong", PvpRules.insideSquare(ox, oz, half), `{ox}, {oz}`)

	-- Berakhir (maju waktu sementara) lalu cooldown 10 menit.
	Clock.advance(61)
	T.wait(0.4)
	Clock.advance(-61)
	T.check(
		"Shield berakhir: kubah hilang, atribut 0",
		findDome(userId) == nil
			and plot:GetAttribute(Attr.ShieldUntil) == 0
			and DefenseService.getShieldRemaining(userId) == 0
	)
	local again2, err2 = DefenseService.activateShield(userId)
	T.check(
		"Shield cooldown menolak",
		again2 == false and err2 ~= nil and string.find(err2, "recharging") ~= nil,
		err2
	)

	-- Pen level 4: +15 detik.
	data.shieldReadyAt = 0
	data.penLevel = 4
	DefenseService.activateShield(userId)
	now = Clock.now()
	untilAt = plot:GetAttribute(Attr.ShieldUntil)
	T.check("durasi Shield 75 detik di pen 4", math.abs(untilAt - (now + 75)) <= 2, untilAt - now)
	DefenseService.endShield(userId)
	data.penLevel = 1

	-- Pemilik (bot) keluar: kubah dan atribut hilang.
	Bots.moveTo(PLAIN, floorPos.X + 200, 3, floorPos.Z)
	local botPlot = PlotService.getPlot(PLAIN)
	DataService.getByUserId(PLAIN).shieldReadyAt = 0
	T.check(
		"Shield bot aktif",
		DefenseService.activateShield(PLAIN) == true and findDome(PLAIN) ~= nil
	)
	Bots.remove(PLAIN)
	T.check(
		"pemilik keluar: kubah dihapus dan atribut 0",
		findDome(PLAIN) == nil and botPlot:GetAttribute(Attr.ShieldUntil) == 0
	)

	-- ===== Bersih-bersih =====
	Bots.removeAll()
	DataService.wipe(userId) -- onLeaving: trap/kubah milik pemain dihapus
	T.wait(1.2)
	local stats = DefenseService.stats()
	T.check(
		"tidak ada trap/kubah/stun/terjebak tersisa",
		stats.traps == 0 and stats.shields == 0 and stats.trapped == 0 and stats.stunned == 0,
		`{stats.traps}/{stats.shields}/{stats.trapped}/{stats.stunned}`
	)
	T.check(
		"tidak ada Part trap/kubah di dunia",
		trapParts(userId) == 0 and findDome(userId) == nil
	)
	T.wait(0.5)
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
