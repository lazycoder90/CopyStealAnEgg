--!nonstrict
-- FriendBoostService: +10% income per teman yang sedang ada di server, maksimal +50%.
-- Pertemanan dicek lewat Player:IsFriendsWith (pcall, yield) dan di-cache per pasangan berurutan
-- selama sesi. Dihitung ulang tiap ada yang join/leave. Bot/pemain virtual tidak pernah dihitung
-- karena hanya Players:GetPlayers() yang diperiksa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local IncomeService = require(script.Parent.IncomeService)
local StateReplicator = require(script.Parent.StateReplicator)

local FriendBoostService = {}

local RESEND_SECONDS = 5

local boosts = {} -- [userId] = 0..max
local friendCounts = {} -- [userId] = jumlah teman di server
local pairCache = {} -- ["a:b"] = boolean
local running = false
local dirty = false

local function areFriends(a: Player, b: Player): boolean
	local key = `{a.UserId}:{b.UserId}`
	local cached = pairCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = ok and result == true
	if ok then
		pairCache[key] = value
	end
	return value
end

local function replicateAll()
	for _, player in Players:GetPlayers() do
		StateReplicator.set(player.UserId, "friendBoost", boosts[player.UserId] or 0)
	end
end

-- Hitung ulang untuk semua pemain nyata. Boleh yield; panggilan bertumpuk digabung.
function FriendBoostService.recompute()
	dirty = true
	if running then
		return
	end
	running = true
	while dirty do
		dirty = false
		local list = {}
		for _, player in Players:GetPlayers() do
			if player.Parent == Players then
				table.insert(list, player)
			end
		end
		local newBoosts, newCounts = {}, {}
		for _, player in list do
			local count = 0
			for _, other in list do
				if other ~= player and areFriends(player, other) then
					count += 1
				end
			end
			newCounts[player.UserId] = count
			newBoosts[player.UserId] = EconomyConfig.friendBoost(count)
		end
		boosts, friendCounts = newBoosts, newCounts
		replicateAll()
	end
	running = false
end

function FriendBoostService.get(userId: number): number
	return boosts[userId] or 0
end

function FriendBoostService.Init()
	IncomeService.addBonus("friends", function(userId)
		return boosts[userId] or 0
	end)

	-- order 1100: setelah snapshot StateReplicator (1000).
	PlayerLifecycle.onJoin("FriendBoostService.replicate", 1100, function(ctx)
		if not ctx.player then
			return
		end
		if boosts[ctx.userId] == nil then
			task.spawn(FriendBoostService.recompute)
		else
			StateReplicator.set(ctx.userId, "friendBoost", boosts[ctx.userId])
		end
	end)
	PlayerLifecycle.onLeaving("FriendBoostService", 100, function(ctx)
		boosts[ctx.userId] = nil
		friendCounts[ctx.userId] = nil
		local prefix, suffix = `{ctx.userId}:`, `:{ctx.userId}`
		for key in pairCache do
			if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then
				pairCache[key] = nil
			end
		end
	end)

	TestBridge.register("friend.info", function(userId)
		return { boost = boosts[userId] or 0, friends = friendCounts[userId] or 0 }
	end)
	TestBridge.register("friend.recompute", function()
		FriendBoostService.recompute()
		return true
	end)
end

function FriendBoostService.Start()
	-- Players dipakai HANYA untuk memicu hitung ulang (bukan untuk data game).
	Players.PlayerAdded:Connect(function()
		task.spawn(FriendBoostService.recompute)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(FriendBoostService.recompute)
	end)
	task.spawn(FriendBoostService.recompute)

	-- Handler kedua ClientReady: kirim nilai setelah StateReplicator siap menerima patch.
	Net.on("ClientReady", Check.args(), function(player)
		task.delay(0.5, function()
			StateReplicator.set(player.UserId, "friendBoost", boosts[player.UserId] or 0)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(RESEND_SECONDS)
			replicateAll()
		end
	end)
end

return FriendBoostService
