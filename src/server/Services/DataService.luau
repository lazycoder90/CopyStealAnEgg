--!nonstrict
-- DataService: memuat/menyimpan profil pemain (ProfileStore), kunci = userId (number).
-- Mendukung "pemain virtual" (bot uji) lewat registerVirtual.
--
-- ATURAN: jangan menyimpan referensi tabel data di service lain; selalu ambil lewat
-- DataService.getByUserId(userId) karena tabel data berganti setelah simulateRejoin.
-- Urutan lepas profil: onLeaving hooks (PlayerLifecycle) dulu, BARU EndSession.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Config.Constants)
local Creatures = require(Shared.Config.Creatures)
local Template = require(Shared.Config.ProfileTemplate)
local Signal = require(Shared.Util.Signal)

local Systems = script.Parent.Parent.Systems
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local Clock = require(Systems.Clock)

local DataService = {}
DataService.onLoaded = Signal.new() -- (player, data) untuk pemain nyata

local entries = {} -- [userId] = { profile, player, virtual, releasing }
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

DataService.deepCopy = deepCopy

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

local function makeCtx(userId: number, entry)
	return {
		userId = userId,
		player = entry.player,
		data = entry.profile.Data,
		name = if entry.player then entry.player.Name else `Bot{userId}`,
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

function DataService.isPersistent(): boolean
	return persistent
end

function DataService.getByUserId(userId: number)
	local entry = entries[userId]
	return entry and not entry.releasing and entry.profile.Data or nil
end

function DataService.get(player: Player)
	return DataService.getByUserId(player.UserId)
end

-- Daftar semua pemain aktif (nyata + virtual): { {userId, data, player, virtual}, ... }
function DataService.all()
	local list = {}
	for userId, entry in entries do
		if not entry.releasing then
			table.insert(list, {
				userId = userId,
				data = entry.profile.Data,
				player = entry.player,
				virtual = entry.virtual == true,
			})
		end
	end
	return list
end

local function startSession(player: Player)
	local userId = player.UserId
	local profile = store:StartSessionAsync(`{userId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("Data gagal dimuat. Silakan coba lagi.")
		end
		return nil
	end

	profile:AddUserId(userId)
	profile:Reconcile()
	Creatures.migrateProfile(profile.Data)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	local entry = { profile = profile, player = player, virtual = false, releasing = false }
	profile.OnSessionEnd:Connect(function()
		if entry.releasing then
			return
		end
		-- Sesi hilang di luar kehendak kita (mis. server lain mengambil profil).
		entry.releasing = true
		PlayerLifecycle.runLeaving(makeCtx(userId, entry))
		if entries[userId] == entry then
			entries[userId] = nil
		end
		if player.Parent == Players then
			player:Kick("Sesi data berakhir. Silakan bergabung lagi.")
		end
	end)

	entries[userId] = entry
	return entry
end

local function release(userId: number)
	local entry = entries[userId]
	if not entry or entry.releasing then
		return
	end
	entry.releasing = true
	local ctx = makeCtx(userId, entry)
	PlayerLifecycle.runLeaving(ctx)
	entry.profile.Data.lastOnline = Clock.now()
	entry.profile:EndSession()
	entries[userId] = nil
end

local function onPlayerAdded(player: Player)
	local entry = startSession(player)
	if not entry then
		return
	end
	PlayerLifecycle.runJoin(makeCtx(player.UserId, entry))
	DataService.onLoaded:Fire(player, entry.profile.Data)
end

-- Pemain virtual (bot uji PvP). Mengembalikan tabel data.
function DataService.registerVirtual(userId: number, data: any?, character: Model?)
	assert(entries[userId] == nil, "userId sudah terdaftar: " .. tostring(userId))
	local profile = {
		Data = data or deepCopy(Template),
		EndSession = function() end,
	}
	local entry = {
		profile = profile,
		player = nil,
		virtual = true,
		releasing = false,
		character = character,
	}
	entries[userId] = entry
	PlayerLifecycle.runJoin(makeCtx(userId, entry))
	return profile.Data
end

function DataService.unregisterVirtual(userId: number)
	local entry = entries[userId]
	if entry and entry.virtual then
		release(userId)
	end
end

-- Mengatur ulang data pemain ke template (admin /wipe). Hook onLeaving membersihkan dunia,
-- lalu onJoin membangunnya kembali dari data kosong.
function DataService.wipe(userId: number)
	local entry = entries[userId]
	if not entry or entry.releasing then
		return nil
	end
	PlayerLifecycle.runLeaving(makeCtx(userId, entry))
	local data = entry.profile.Data
	for k in data do
		data[k] = nil
	end
	for k, v in deepCopy(Template) do
		data[k] = v
	end
	PlayerLifecycle.runJoin(makeCtx(userId, entry))
	return data
end

-- Uji: meniru keluar lalu masuk lagi (onLeaving -> lepas profil -> muat ulang -> onJoin).
function DataService.simulateRejoin(userId: number): boolean
	local entry = entries[userId]
	assert(entry and entry.player and not entry.virtual, "simulateRejoin hanya untuk pemain nyata")
	local player = entry.player
	release(userId)
	local newEntry = startSession(player)
	if not newEntry then
		return false
	end
	PlayerLifecycle.runJoin(makeCtx(userId, newEntry))
	return true
end

function DataService.Start()
	-- Perbarui lastOnline tiap 30 detik (tahan crash; dipakai penghasilan offline).
	local counter = 0
	Clock.every1Hz(function()
		counter += 1
		if counter < 30 then
			return
		end
		counter = 0
		local now = Clock.now()
		for _, item in DataService.all() do
			item.data.lastOnline = now
		end
	end)
end

-- Dipanggil Boot setelah SEMUA Init/Start selesai, sehingga semua hook sudah terdaftar.
function DataService.Ready()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player.UserId)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local ids = {}
		for userId in entries do
			table.insert(ids, userId)
		end
		for _, userId in ids do
			release(userId)
		end
	end)
end

return DataService
