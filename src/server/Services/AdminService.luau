--!nonstrict
-- Admin command untuk pengujian. Di Studio semua pemain boleh; di server live hanya ADMIN_USER_IDS.
-- Dipanggil dari remote AdminCommand atau chat "/cash 1e6".
-- Command baru didaftarkan service lain lewat AdminService.register(name, fn(player, args) -> string).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Config.Constants)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Clock = require(Systems.Clock)

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StateReplicator = require(script.Parent.StateReplicator)

local AdminService = {}

local commands = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Constants.ADMIN_USER_IDS, player.UserId) ~= nil
end

function AdminService.register(name: string, fn: (Player, { string }) -> string)
	commands[string.lower(name)] = fn
end

commands.cash = function(player, args)
	local amount = tonumber(args[1])
	if not amount or not CurrencyService.set(player.UserId, "cash", amount) then
		return "Pakai: cash <angka >= 0>"
	end
	return `cash = {amount}`
end

commands.speed = function(player, args)
	local amount = tonumber(args[1])
	if not amount or not CurrencyService.set(player.UserId, "speedBase", amount) then
		return "Pakai: speed <angka >= 0>"
	end
	return `speedBase = {amount}`
end

commands.wipe = function(player)
	if not DataService.wipe(player.UserId) then
		return "Data belum dimuat"
	end
	return "Data direset"
end

commands.resync = function(player)
	StateReplicator.resync(player.UserId)
	return "State dikirim ulang"
end

commands.timescale = function(_, args)
	local k = tonumber(args[1])
	if not (k and k > 0 and k <= 1000) then
		return "Pakai: timescale <1..1000>"
	end
	Clock.timeScale = k
	return `timeScale = {k}`
end

commands.advance = function(_, args)
	local seconds = tonumber(args[1])
	if not (RunService:IsStudio() and seconds and seconds >= 0 and seconds <= 7 * 86400) then
		return "Pakai (Studio saja): advance <detik 0..604800>"
	end
	Clock.advance(seconds)
	return `waktu maju {seconds} detik`
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
	local ok, result = pcall(handler, player, parts)
	if not ok then
		return "Error: " .. tostring(result)
	end
	return result
end

function AdminService.Start()
	Net.on("AdminCommand", Check.args(Check.str(100)), function(player, line)
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
