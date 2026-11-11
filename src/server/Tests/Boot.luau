--!nonstrict
-- Skenario uji dasar: boot, remote, data, replikasi, mata uang, lifecycle.
-- Dijalankan lewat: ServerStorage.TestBridge:Invoke("test.run", "Boot")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Boot = require(Server.Boot)
local DataService = require(Server.Services.DataService)
local CurrencyService = require(Server.Services.CurrencyService)
local Clock = require(Server.Systems.Clock)

return function(T)
	T.check("tidak ada modul boot yang gagal", #Boot.failed == 0, #Boot.failed .. " gagal")
	T.check("TestBridge ada", ServerStorage:FindFirstChild("TestBridge") ~= nil)

	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	T.check("folder Remotes ada", folder ~= nil)
	if folder then
		local missing = {}
		for name in Remotes.C2S do
			if not folder:FindFirstChild(name) then
				table.insert(missing, name)
			end
		end
		for _, name in Remotes.S2C do
			if not folder:FindFirstChild(name) then
				table.insert(missing, name)
			end
		end
		T.check("semua remote terbuat", #missing == 0, table.concat(missing, ","))
	end

	if not T.userId then
		T.check("ada pemain untuk uji data", false, "tidak ada pemain (jalankan Play dulu)")
		return
	end

	local data = DataService.getByUserId(T.userId)
	T.check("profil termuat", data ~= nil)
	if not data then
		return
	end

	-- CurrencyService: tolak nilai buruk, terima nilai baik
	local before = data.cash
	T.check("add NaN ditolak", CurrencyService.add(T.userId, "cash", 0 / 0) == false)
	T.check("add inf ditolak", CurrencyService.add(T.userId, "cash", math.huge) == false)
	T.check("add negatif ditolak", CurrencyService.add(T.userId, "cash", -5) == false)
	T.check(
		"spend melebihi saldo ditolak",
		CurrencyService.trySpend(T.userId, "cash", before + 1e12) == false
	)
	T.check(
		"cash tidak berubah setelah penolakan",
		DataService.getByUserId(T.userId).cash == before
	)
	T.check("add valid berhasil", CurrencyService.add(T.userId, "cash", 100) == true)
	T.check("cash bertambah 100", DataService.getByUserId(T.userId).cash == before + 100)
	T.check("spend valid berhasil", CurrencyService.trySpend(T.userId, "cash", 100) == true)
	T.check("cash kembali", DataService.getByUserId(T.userId).cash == before)

	-- Clock
	local t0 = Clock.now()
	Clock.advance(100)
	T.check("Clock.advance menggeser now", Clock.now() - t0 >= 100)
	Clock.advance(-100)
	T.check("Clock offset dipulihkan", math.abs(Clock.now() - t0) <= 1)
end
