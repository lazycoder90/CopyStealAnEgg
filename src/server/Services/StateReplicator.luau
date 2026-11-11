--!nonstrict
-- Mengirim snapshot awal dan patch {path, value} ke klien pemilik data (kunci = userId).
-- Jabat tangan: snapshot baru dikirim setelah klien mengirim ClientReady DAN profil sudah termuat,
-- sehingga snapshot tidak hilang jika klien lebih lambat dari server.
-- Patch dikumpulkan dan dikirim sekali per Heartbeat. Bot (pemain virtual) tidak direplikasi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local DataService = require(script.Parent.DataService)

local StateReplicator = {}

local pending = {} -- [userId] = { {path, value}, ... }
local clientReady = {} -- [userId] = true

local HIDDEN_KEYS = { receipts = true }

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

local function snapshot(data)
	local out = {}
	for k, v in data do
		if not HIDDEN_KEYS[k] then
			out[k] = copy(v)
		end
	end
	return out
end

local function sendInit(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local data = DataService.getByUserId(userId)
	if player and data and clientReady[userId] then
		pending[userId] = nil
		Net.fire("StateInit", player, snapshot(data))
	end
end

-- Kirim ulang seluruh state (dipakai setelah perubahan besar).
function StateReplicator.resync(userId: number)
	sendInit(userId)
end

-- path berupa "cash" atau "settings.slowMode" (dipisah titik).
function StateReplicator.set(userId: number, path: string, value)
	if not clientReady[userId] then
		return -- snapshot awal akan memuat nilai terbaru
	end
	local list = pending[userId]
	if not list then
		list = {}
		pending[userId] = list
	end
	table.insert(list, { path, value })
end

function StateReplicator.Init()
	PlayerLifecycle.onJoin("StateReplicator", 1000, function(ctx)
		if ctx.player then
			sendInit(ctx.userId)
		end
	end)
	PlayerLifecycle.onLeaving("StateReplicator", 1000, function(ctx)
		pending[ctx.userId] = nil
	end)
end

function StateReplicator.Start()
	Net.on("ClientReady", Check.args(), function(player)
		clientReady[player.UserId] = true
		sendInit(player.UserId)
	end)

	RunService.Heartbeat:Connect(function()
		for userId, list in pending do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				Net.fire("StatePatch", player, list)
			end
			pending[userId] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player.UserId] = nil
		clientReady[player.UserId] = nil
	end)
end

return StateReplicator
