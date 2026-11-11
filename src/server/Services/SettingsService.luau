--!nonstrict
-- SettingsService: pengaturan pemain (music, sfx, lowGfx) di data.settings. slowMode punya remote sendiri
-- (SetSlowMode di SpeedService). Hook TestBridge: settings.get(userId).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local InvariantChecker = require(Systems.InvariantChecker)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local SettingsService = {}

local KEYS = { "music", "sfx", "lowGfx" }

function SettingsService.set(userId: number, key: string, value: boolean): boolean
	local data = DataService.getByUserId(userId)
	if not (data and table.find(KEYS, key) and type(value) == "boolean") then
		return false
	end
	data.settings[key] = value
	StateReplicator.set(userId, `settings.{key}`, value)
	return true
end

function SettingsService.Init()
	InvariantChecker.register("Settings", function(entry)
		local out = {}
		for key, value in entry.data.settings do
			if type(value) ~= "boolean" then
				table.insert(out, `settings.{tostring(key)} bukan boolean`)
			end
		end
		return out
	end)

	TestBridge.register("settings.get", function(userId)
		local data = DataService.getByUserId(userId)
		return data and table.clone(data.settings)
	end)
end

function SettingsService.Start()
	Net.on("SetSetting", Check.args(Check.enum(KEYS), Check.bool), function(player, key, value)
		SettingsService.set(player.UserId, key, value)
	end)
end

return SettingsService
