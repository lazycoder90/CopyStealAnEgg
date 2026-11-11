--!nonstrict
-- InventoryService: kantong telur (pocket). Telur placed bisa dimasukkan ke kantong (progress tersimpan,
-- tidak tumbuh) dan ditaruh kembali lewat PlacementService.validate/insert.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Check = require(Shared.Util.Check)
local Eggs = require(Shared.Config.Eggs)
local Net = require(Shared.Net.Net)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local InvariantChecker = require(Systems.InvariantChecker)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local PlacementService = require(script.Parent.PlacementService)
local StateReplicator = require(script.Parent.StateReplicator)

local InventoryService = {}

function InventoryService.pocketCount(data): number
	local n = 0
	for _, egg in data.eggs do
		if egg.loc == "pocket" then
			n += 1
		end
	end
	return n
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

-- Masukkan telur placed ke kantong. Mengembalikan true atau false + pesan galat.
function InventoryService.pocket(userId: number, uid: string): (boolean, string?)
	local data = DataService.getByUserId(userId)
	local egg = data and data.eggs[uid]
	if not egg or egg.loc ~= "placed" then
		return false, "Egg not found."
	end
	if GrowthService.isFrozen(userId, uid) then
		return false, "That egg is being stolen!"
	end
	if InventoryService.pocketCount(data) >= Eggs.pocketCapacity then
		return false, `Your pocket is full! ({Eggs.pocketCapacity}/{Eggs.pocketCapacity})`
	end
	egg.loc = "pocket"
	egg.pos = nil
	GrowthService.removeModel(userId, uid)
	StateReplicator.set(userId, `eggs.{uid}.loc`, "pocket")
	StateReplicator.set(userId, `eggs.{uid}.pos`, nil)
	return true
end

-- Taruh telur kantong di dunia. Mengembalikan true, nil, uid atau false + pesan galat.
function InventoryService.place(
	userId: number,
	uid: string,
	pos: Vector3
): (boolean, string?, string?)
	local data = DataService.getByUserId(userId)
	local egg = data and data.eggs[uid]
	if not egg or egg.loc ~= "pocket" then
		return false, "Egg not found."
	end
	local ok, err, lx, lz = PlacementService.validate(userId, pos)
	if not ok then
		return false, err
	end
	-- Atomik: salin data, hapus dari profil, lalu masukkan lewat PlacementService.insert.
	local copy = {
		uid = uid,
		id = egg.id,
		kg = egg.kg,
		muts = egg.muts,
		growTotal = egg.growTotal,
		progress = egg.progress,
		stolenFrom = egg.stolenFrom,
	}
	data.eggs[uid] = nil
	StateReplicator.set(userId, `eggs.{uid}`, nil)
	local newUid = PlacementService.insert(userId, copy, lx, lz)
	return true, nil, newUid
end

function InventoryService.Init()
	InvariantChecker.register("Inventory", function(entry)
		local out = {}
		local count = InventoryService.pocketCount(entry.data)
		if count > Eggs.pocketCapacity then
			table.insert(out, `pocket {count} > kapasitas {Eggs.pocketCapacity}`)
		end
		for uid, egg in entry.data.eggs do
			if egg.loc == "pocket" then
				if egg.pos ~= nil then
					table.insert(out, `egg {uid} pocket masih punya pos`)
				end
				if GrowthService.getModel(entry.userId, uid) then
					table.insert(out, `egg {uid} pocket masih punya model`)
				end
			end
		end
		return out
	end)

	TestBridge.register("inventory.pocket", function(userId, uid)
		local ok, err = InventoryService.pocket(userId, uid)
		return { ok = ok, err = err }
	end)
	TestBridge.register("inventory.place", function(userId, uid, x, y, z)
		local ok, err, newUid = InventoryService.place(userId, uid, Vector3.new(x, y, z))
		return { ok = ok, err = err, uid = newUid }
	end)
end

function InventoryService.Start()
	Net.on("PocketEgg", Check.args(Check.uid), function(player, uid)
		local ok, err = InventoryService.pocket(player.UserId, uid)
		if not ok and err then
			notify(player.UserId, err, "error")
		end
	end)
	Net.on("PlaceFromInventory", Check.args(Check.uid, Check.vec3), function(player, uid, pos)
		local ok, err = InventoryService.place(player.UserId, uid, pos)
		if not ok and err then
			notify(player.UserId, err, "error")
		end
	end)
end

return InventoryService
