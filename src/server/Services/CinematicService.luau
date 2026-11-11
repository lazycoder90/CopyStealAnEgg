--!nonstrict
-- CinematicService: intro sinematik hanya sekali per profil. Klien tidak pernah menulis bendera;
-- server mengisi data.cinematicSeen = true sendiri 40 detik setelah profil baru bergabung
-- (profil lama dengan tutorial.done langsung true) dan mereplikasinya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PolishConfig = require(Shared.Config.PolishConfig)

local Systems = script.Parent.Parent.Systems
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local CinematicService = {}

local tokens = {} -- [userId] = nomor jadwal aktif (membatalkan jadwal lama)

-- Menandai sudah ditonton; selalu ambil tabel data terbaru (tabel berganti saat simulateRejoin).
function CinematicService.markSeen(userId: number): boolean
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	data.cinematicSeen = true
	StateReplicator.set(userId, "cinematicSeen", true)
	return true
end

local function schedule(userId: number)
	local token = (tokens[userId] or 0) + 1
	tokens[userId] = token
	task.delay(PolishConfig.cinematicSeenDelay, function()
		if tokens[userId] == token then
			tokens[userId] = nil
			CinematicService.markSeen(userId)
		end
	end)
end

function CinematicService.Init()
	-- order 1100: setelah snapshot StateReplicator (1000), sehingga patch ikut terkirim.
	PlayerLifecycle.onJoin("CinematicService", 1100, function(ctx)
		local data = ctx.data
		local done = data.tutorial and data.tutorial.done == true
		if data.cinematicSeen == true then
			return
		end
		if done then
			CinematicService.markSeen(ctx.userId)
		else
			schedule(ctx.userId)
		end
	end)
	PlayerLifecycle.onLeaving("CinematicService", 100, function(ctx)
		tokens[ctx.userId] = nil
	end)

	-- Uji: jalankan fungsi penjadwalan sekarang juga (tanpa menunggu 40 detik).
	TestBridge.register("cinematic.fastForward", function(userId)
		tokens[userId] = nil
		return CinematicService.markSeen(userId)
	end)
end

return CinematicService
