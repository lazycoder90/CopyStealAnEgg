--!nonstrict
-- DataService: memuat/menyimpan profil pemain.
-- Memakai ProfileStore (loleris) jika ada di src/server/Vendor/ProfileStore.luau.
-- Jika belum ada, memakai penyimpanan di memori (TIDAK persisten) supaya pengembangan tetap jalan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Config.Constants)
local Template = require(Shared.Config.ProfileTemplate)
local Signal = require(Shared.Util.Signal)

local DataService = {}
DataService.onLoaded = Signal.new() -- (player, data)

local profiles = {}
local store
local persistent = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Pengganti sementara bila ProfileStore belum dipasang.
local function makeMemoryStore()
	local memory = {}
	return {
		StartSessionAsync = function(_, key)
			local data = memory[key] or deepCopy(Template)
			memory[key] = data
			return {
				Data = data,
				AddUserId = function() end,
				Reconcile = function() end,
				EndSession = function() end,
				OnSessionEnd = Signal.new(),
			}
		end,
	}
end

function DataService.Init()
	local vendor = script.Parent.Parent:FindFirstChild("Vendor")
	local module = vendor and vendor:FindFirstChild("ProfileStore")
	if module then
		local ProfileStore = require(module)
		local name = if RunService:IsStudio()
			then Constants.DATA_STORE_NAME_DEV
			else Constants.DATA_STORE_NAME
		store = ProfileStore.New(name, Template)
		persistent = true
	else
		warn(
			"[DataService] ProfileStore tidak ditemukan di src/server/Vendor. Data TIDAK akan tersimpan."
		)
		store = makeMemoryStore()
	end
end

function DataService.isPersistent()
	return persistent
end

function DataService.get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Reset data pemain ke template (dipakai /wipe).
function DataService.wipe(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for k in data do
		data[k] = nil
	end
	for k, v in deepCopy(Template) do
		data[k] = v
	end
	return data
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Data gagal dimuat. Silakan coba lagi.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sesi data berakhir. Silakan bergabung lagi.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	DataService.onLoaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data.lastOnline = os.time()
		profile:EndSession()
		profiles[player] = nil
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
