--!nonstrict
-- IndexService: Pet Index. data.index = { found, claimed, zoneBonus }.
-- found ditandai oleh HatchService (langsung di data) dan FuseService (markFound); service ini mengevaluasi
-- zona lengkap (+2% income lewat IncomeService.addBonus) saat join, setelah hatch, dan setelah fuse.
-- Claim memberi cash dan speedBase lewat CurrencyService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Zones = require(Shared.Config.Zones)
local IndexMath = require(Shared.Logic.IndexMath)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local GameEvents = require(Systems.GameEvents)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local StateReplicator = require(script.Parent.StateReplicator)

local IndexService = {}

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

local function completedCount(data): number
	local n = 0
	for _ in data.index.zoneBonus do
		n += 1
	end
	return n
end

-- Menandai zona lengkap yang belum tercatat. Mengembalikan daftar zona yang baru lengkap.
function IndexService.evaluate(userId: number): { number }
	local data = DataService.getByUserId(userId)
	if not data then
		return {}
	end
	local newZones = {}
	for _, zone in IndexMath.completedZones(data.index.found) do
		local key = tostring(zone)
		if not data.index.zoneBonus[key] then
			data.index.zoneBonus[key] = true
			StateReplicator.set(userId, `index.zoneBonus.{key}`, true)
			table.insert(newZones, zone)
			notify(userId, "Zone complete! +2% income", "success")
		end
	end
	return newZones
end

-- Menandai spesies ditemukan (idempoten). Mengembalikan true bila baru.
function IndexService.markFound(userId: number, speciesId: string): boolean
	local data = DataService.getByUserId(userId)
	if not (data and Creatures.byId[speciesId]) then
		return false
	end
	local isNew = not data.index.found[speciesId]
	if isNew then
		data.index.found[speciesId] = true
		StateReplicator.set(userId, `index.found.{speciesId}`, true)
	end
	IndexService.evaluate(userId)
	return isNew
end

local function claimOne(userId: number, data, speciesId: string): (number, number)
	local cash, speed = IndexMath.rewards(speciesId)
	CurrencyService.add(userId, "cash", cash)
	CurrencyService.add(userId, "speedBase", speed)
	data.index.claimed[speciesId] = true
	StateReplicator.set(userId, `index.claimed.{speciesId}`, true)
	return cash, speed
end

local function claimMessage(cash: number, speed: number): string
	return `Claimed: {NumberFormat.fmtMoney(cash)} and +{NumberFormat.fmt(speed)} speed`
end

-- Claim satu spesies. Mengembalikan true, cash, speed atau false, pesan galat.
function IndexService.claim(userId: number, speciesId: string): (boolean, any, any)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded.", nil
	end
	if not Creatures.byId[speciesId] then
		return false, "Unknown creature.", nil
	end
	if not data.index.found[speciesId] then
		return false, "You haven't discovered this creature yet.", nil
	end
	if data.index.claimed[speciesId] then
		return false, "Already claimed.", nil
	end
	local cash, speed = claimOne(userId, data, speciesId)
	notify(userId, claimMessage(cash, speed), "success")
	return true, cash, speed
end

-- Claim semua yang belum diambil. Mengembalikan true, cash, speed, jumlah atau false, pesan galat.
function IndexService.claimAll(userId: number): (boolean, any, any, any)
	local data = DataService.getByUserId(userId)
	if not data then
		return false, "Data not loaded.", nil, nil
	end
	local list = IndexMath.unclaimedList(data.index.found, data.index.claimed)
	if #list == 0 then
		return false, "Nothing to claim.", nil, nil
	end
	local cash, speed = 0, 0
	for _, id in list do
		local c, s = claimOne(userId, data, id)
		cash += c
		speed += s
	end
	notify(userId, claimMessage(cash, speed), "success")
	return true, cash, speed, #list
end

function IndexService.Init()
	IncomeService.addBonus("index", function(userId)
		local data = DataService.getByUserId(userId)
		return data and IndexMath.zoneBonus(completedCount(data)) or 0
	end)

	PlayerLifecycle.onJoin("IndexService", 100, function(ctx)
		IndexService.evaluate(ctx.userId)
	end)

	InvariantChecker.register("Index", function(entry)
		local out = {}
		local index = entry.data.index
		for id in index.claimed do
			if not index.found[id] then
				table.insert(out, `index claimed tanpa found: {id}`)
			end
		end
		for id in index.found do
			if not Creatures.byId[id] then
				table.insert(out, `index found id tidak dikenal: {id}`)
			end
		end
		for key in index.zoneBonus do
			local zone = tonumber(key)
			if not (zone and Zones.list[zone] and IndexMath.isZoneComplete(index.found, zone)) then
				table.insert(out, `zoneBonus tanpa zona lengkap: {key}`)
			end
		end
		return out
	end)

	TestBridge.register("index.evaluate", function(userId)
		return IndexService.evaluate(userId)
	end)
	TestBridge.register("index.claim", function(userId, speciesId)
		local ok, a, b = IndexService.claim(userId, speciesId)
		return { ok = ok, cash = a, speed = b }
	end)
	TestBridge.register("index.claimAll", function(userId)
		local ok, a, b, n = IndexService.claimAll(userId)
		return { ok = ok, cash = a, speed = b, count = n }
	end)
end

function IndexService.Start()
	GameEvents.EggHatched:Connect(function(payload)
		IndexService.evaluate(payload.userId)
	end)

	Net.on("ClaimIndex", Check.args(Check.uid), function(player, speciesId)
		local ok, err = IndexService.claim(player.UserId, speciesId)
		if not ok then
			Net.fire("Notify", player, err, "error")
		end
	end)
	Net.on("ClaimIndexAll", Check.args(), function(player)
		local ok, err = IndexService.claimAll(player.UserId)
		if not ok then
			Net.fire("Notify", player, err, "error")
		end
	end)
end

return IndexService
