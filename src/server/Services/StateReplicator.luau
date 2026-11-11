--!nonstrict
-- Mengirim snapshot awal dan patch {path, value} ke klien pemilik data.
-- Patch dikumpulkan dan dikirim sekali per Heartbeat agar tidak membanjiri jaringan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local StateReplicator = {}

local pending = {} -- [player] = { {path, value}, ... }

local HIDDEN_KEYS = { receipts = true }

local function snapshot(data)
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
	local out = {}
	for k, v in data do
		if not HIDDEN_KEYS[k] then
			out[k] = copy(v)
		end
	end
	return out
end

function StateReplicator.init(player: Player, data)
	pending[player] = nil
	Net.fire("StateInit", player, snapshot(data))
end

-- path berupa "cash" atau "settings.slowMode" (dipisah titik).
function StateReplicator.set(player: Player, path: string, value)
	local list = pending[player]
	if not list then
		list = {}
		pending[player] = list
	end
	table.insert(list, { path, value })
end

function StateReplicator.Start()
	RunService.Heartbeat:Connect(function()
		for player, list in pending do
			if player.Parent == Players then
				Net.fire("StatePatch", player, list)
			end
			pending[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return StateReplicator
