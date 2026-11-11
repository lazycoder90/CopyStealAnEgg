--!nonstrict
-- PlacementService: menaruh telur yang dibawa ke Coop sendiri (validasi berurutan, server-authoritative).
-- Urutan galat: tooFar -> badSpot -> tooClose -> coopFull (teks persis dari Config/Eggs.messages).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local TestBridge = require(Systems.TestBridge)

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local PlotService = require(script.Parent.PlotService)
local StateReplicator = require(script.Parent.StateReplicator)

local PlacementService = {}

local MAX_TARGET_DISTANCE = 40 -- target tidak boleh jauh dari pemain (cegah penempatan jarak jauh)

local function newUid(): string
	return string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
end

local function placedCount(data): number
	local n = 0
	for _, egg in data.eggs do
		if egg.loc == "placed" then
			n += 1
		end
	end
	return n
end

-- Mengembalikan true, atau false + pesan galat.
function PlacementService.place(userId: number, worldPos: Vector3): (boolean, string?)
	if not CarryService.isCarrying(userId) then
		return false, Eggs.messages.notCarrying
	end
	local data = DataService.getByUserId(userId)
	local plot = PlotService.getPlot(userId)
	local root = Actors.getRoot(userId)
	if not (data and plot and root) then
		return false, Eggs.messages.tooFar
	end

	-- 1. Pemain harus dekat Coop sendiri dan target dekat pemain.
	if PlotService.distanceToPlot(plot, root.Position) > Eggs.placeMaxDistanceFromCoop then
		return false, Eggs.messages.tooFar
	end
	if (worldPos - root.Position).Magnitude > MAX_TARGET_DISTANCE then
		return false, Eggs.messages.tooFar
	end

	-- 2. Target di dalam lantai plot (dengan inset) dan bukan area terlarang.
	local lx, lz = PlotService.worldToLocal(plot, worldPos)
	if
		not PlotService.isInsideLocal(lx, lz, Eggs.placeInset)
		or PlotService.isReservedLocal(lx, lz)
	then
		return false, Eggs.messages.badSpot
	end

	-- 3. Jarak minimal dari telur lain di Coop ini.
	for _, egg in data.eggs do
		if egg.loc == "placed" and egg.pos then
			local dx, dz = lx - egg.pos.x, lz - egg.pos.z
			if dx * dx + dz * dz < Eggs.placeMinSpacing * Eggs.placeMinSpacing then
				return false, Eggs.messages.tooClose
			end
		end
	end

	-- 4. Kapasitas Coop.
	if placedCount(data) >= Progression.eggSlotsFor(data.penLevel, data.plotExpansion) then
		return false, Eggs.messages.coopFull
	end

	-- Semua lolos: serahkan telur dan masukkan ke profil (tanpa yield, atomik).
	local egg = CarryService.consume(userId)
	if not egg then
		return false, Eggs.messages.notCarrying
	end
	local uid = egg.uid
	if data.eggs[uid] then
		uid = newUid()
	end

	local growTotal = egg.growTotal
	if (data.stats.hatched or 0) == 0 and not data.tutorial.done then
		growTotal = math.min(growTotal, Eggs.tutorialGrowSeconds) -- telur pertama cepat menetas
	end

	data.eggs[uid] = {
		id = egg.id,
		kg = egg.kg,
		muts = egg.muts or {},
		growTotal = growTotal,
		progress = egg.progress or 0,
		loc = "placed",
		pos = { x = lx, z = lz },
		stolenFrom = egg.stolenFrom,
		t = Clock.now(),
	}
	StateReplicator.set(userId, `eggs.{uid}`, data.eggs[uid])
	GrowthService.ensureModel(userId, uid)

	GameEvents.EggPlaced:Fire({
		userId = userId,
		eggUid = uid,
		speciesId = egg.id,
		stolen = egg.stolenFrom ~= nil,
	})
	return true
end

function PlacementService.Init()
	TestBridge.register("place.at", function(userId, x, y, z)
		local ok, err = PlacementService.place(userId, Vector3.new(x, y, z))
		return { ok = ok, err = err }
	end)
end

function PlacementService.Start()
	Net.on("PlaceEgg", Check.args(Check.vec3), function(player, pos)
		local ok, err = PlacementService.place(player.UserId, pos)
		if not ok and err then
			CarryService.notify(player.UserId, err, "error")
		end
	end)
end

return PlacementService
