--!nonstrict
-- Admin command untuk pengujian. Di Studio semua pemain boleh; di server live hanya ADMIN_USER_IDS.
-- Dipanggil dari AdminPanel klien (Net: AdminCommand) atau chat "/cash 1e6".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Config.Constants)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)
local Clock = require(script.Parent.Parent.Systems.Clock)

local AdminService = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Constants.ADMIN_USER_IDS, player.UserId) ~= nil
end

local commands = {}

function commands.cash(player, args)
	local amount = tonumber(args[1])
	local data = DataService.get(player)
	if not (amount and data) then
		return "Pakai: cash <angka>"
	end
	data.cash = amount
	StateReplicator.set(player, "cash", amount)
	return `cash = {amount}`
end

function commands.speed(player, args)
	local amount = tonumber(args[1])
	local data = DataService.get(player)
	if not (amount and data) then
		return "Pakai: speed <angka>"
	end
	data.speedBase = amount
	StateReplicator.set(player, "speedBase", amount)
	return `speedBase = {amount}`
end

function commands.wipe(player)
	local data = DataService.wipe(player)
	if not data then
		return "Data belum dimuat"
	end
	StateReplicator.init(player, data)
	return "Data direset"
end

function commands.timescale(_, args)
	local k = tonumber(args[1])
	if not (k and k > 0 and k <= 1000) then
		return "Pakai: timescale <1..1000>"
	end
	Clock.timeScale = k
	return `timeScale = {k}`
end

function AdminService.run(player: Player, line: string): string
	if not isAdmin(player) then
		return "Tidak diizinkan"
	end
	local stripped = string.gsub(line, "^/", "")
	local parts = string.split(stripped, " ")
	local name = string.lower(table.remove(parts, 1) or "")
	local handler = commands[name]
	if not handler then
		return "Command tidak dikenal: " .. name
	end
	return handler(player, parts)
end

function AdminService.Start()
	Net.on("AdminCommand", function(player, line)
		if type(line) ~= "string" or #line > 100 then
			return
		end
		Net.fire("Notify", player, AdminService.run(player, line), "admin")
	end)

	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" and isAdmin(player) then
				Net.fire("Notify", player, AdminService.run(player, message), "admin")
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return AdminService
