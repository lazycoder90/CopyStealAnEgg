--!nonstrict
-- OfflineEarningsService: penghasilan offline dihitung SEKALI saat join (docs/CHANGES.md #4).
-- Hanya jika lastOnline > 0. Memakai lastIncomePerSec TERSIMPAN (bukan hitung ulang).
-- Berjalan di order 20, sebelum GrowthService (50), sehingga model telur dibuat dari progress baru.
-- Banner dikirim lewat remote OfflineEarnings; bila klien belum ClientReady, pesan ditahan di memori.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local OfflineMath = require(Shared.Logic.OfflineMath)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Clock = require(Systems.Clock)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local StateReplicator = require(script.Parent.StateReplicator)

local OfflineEarningsService = {}

local capMultipliers = {} -- [name] = fn(userId) -> number
local pendingBanner = {} -- [userId] = { amount, perDay } menunggu ClientReady
local lastBanner = {} -- [userId] = payload terakhir (untuk uji)
local clientReady = {} -- [userId] = true setelah klien mengirim ClientReady

-- Pengali batas offline tambahan (mis. VIP x2). fn(userId) -> number > 0.
function OfflineEarningsService.addCapMultiplier(name: string, fn: (number) -> number)
	capMultipliers[name] = fn
end

local function capFor(userId: number, data): number
	local extra = 1
	for _, fn in capMultipliers do
		local ok, value = pcall(fn, userId)
		if ok and type(value) == "number" and value == value and value > 0 then
			extra *= value
		end
	end
	return OfflineMath.capSeconds(data.penLevel or 1, extra)
end

local function sendBanner(userId: number, payload)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fire("OfflineEarnings", player, payload.amount, payload.perDay)
	end
end

-- Satu kali per join. Mengembalikan ringkasan { elapsed, earned, cap }.
local function process(userId: number, data)
	local now = Clock.now()
	local cap = capFor(userId, data)
	local elapsed = OfflineMath.elapsed(now, data.lastOnline or 0, cap)
	local income = data.lastIncomePerSec or 0
	local earned = Formulas.offlineEarned(income, elapsed, cap)
	lastBanner[userId] = nil
	pendingBanner[userId] = nil

	if earned > 0 then
		CurrencyService.add(userId, "cash", earned)
	end

	if elapsed > 0 then
		for uid, egg in data.eggs do
			if egg.loc == "placed" and not GrowthService.isFrozen(userId, uid) then
				local progress = OfflineMath.advanceEgg(egg.progress, egg.growTotal, elapsed)
				if progress ~= egg.progress then
					egg.progress = progress
					StateReplicator.set(userId, `eggs.{uid}.progress`, progress)
				end
			end
		end
	end

	-- Selalu setel ulang (juga profil baru) agar heartbeat 30 detik punya dasar.
	data.lastOnline = now

	if OfflineMath.shouldShowBanner(earned, elapsed) then
		local payload = { amount = earned, perDay = Formulas.offlinePerDay(income) }
		lastBanner[userId] = payload
		if clientReady[userId] then
			sendBanner(userId, payload)
		elseif Players:GetPlayerByUserId(userId) then
			pendingBanner[userId] = payload
		end
	end
	return { elapsed = elapsed, earned = earned, cap = cap }
end

function OfflineEarningsService.simulate(userId: number, seconds: number?)
	local data = DataService.getByUserId(userId)
	if not data then
		return nil
	end
	if seconds then
		data.lastOnline = Clock.now() - seconds
	end
	return process(userId, data)
end

function OfflineEarningsService.Init()
	PlayerLifecycle.onJoin("OfflineEarningsService", 20, function(ctx)
		process(ctx.userId, ctx.data)
	end)
	PlayerLifecycle.onLeaving("OfflineEarningsService", 20, function(ctx)
		pendingBanner[ctx.userId] = nil
	end)

	InvariantChecker.register("Offline", function(entry)
		local v = entry.data.lastOnline
		if type(v) ~= "number" or v ~= v or v == math.huge or v < 0 then
			return { `lastOnline tidak valid: {tostring(v)}` }
		end
		return {}
	end)

	TestBridge.register("offline.simulate", OfflineEarningsService.simulate)
	TestBridge.register("offline.lastBanner", function(userId)
		return lastBanner[userId]
	end)
end

function OfflineEarningsService.Start()
	-- Handler kedua untuk ClientReady (boleh lebih dari satu): kirim banner yang tertahan.
	Net.on("ClientReady", Check.args(), function(player)
		local userId = player.UserId
		clientReady[userId] = true
		local payload = pendingBanner[userId]
		if payload then
			pendingBanner[userId] = nil
			sendBanner(userId, payload)
		end
	end)

	-- Status koneksi klien (bukan data game) dibersihkan saat pemain benar-benar keluar server.
	Players.PlayerRemoving:Connect(function(player)
		clientReady[player.UserId] = nil
		lastBanner[player.UserId] = nil
	end)
end

return OfflineEarningsService
