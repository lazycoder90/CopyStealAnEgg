--!nonstrict
-- Skenario uji Free Basket. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "FreeBasket")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local BasketRoll = require(Shared.Logic.BasketRoll)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local RNG = require(Shared.Logic.RNG)

local Clock = require(Server.Systems.Clock)
local DataService = require(Server.Services.DataService)
local FreeBasketService = require(Server.Services.FreeBasketService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge
	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		if not r.ok then
			T.check("hook " .. name, false, r.error)
		end
		return r.result
	end

	DataService.wipe(userId)
	T.wait(1.2)
	local data = DataService.getByUserId(userId)
	local petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	T.wait(1.5)
	data = DataService.getByUserId(userId)

	T.check("tersedia di awal", data.freeBasketAt == 0)
	T.check("kios dan prompt ada", workspace:FindFirstChild("FreeBasketStall", true) ~= nil)
	T.check("luck awal x1", FreeBasketService.luckMultiplier(userId) == 1)

	call("basket.setSeed", 77)
	local first = call("basket.claim", userId)
	T.check("klaim pertama berhasil", first.ok == true, first.result)
	data = DataService.getByUserId(userId)
	T.check(
		"cooldown = now + 900",
		math.abs(data.freeBasketAt - (Clock.now() + EconomyConfig.basket.cooldown)) <= 2,
		data.freeBasketAt
	)
	local second = call("basket.claim", userId)
	T.check("klaim kedua ditolak", second.ok == false)
	T.check(
		"sisa waktu dilaporkan",
		second.remaining ~= nil and second.remaining > 880 and second.remaining <= 900,
		second.remaining
	)

	Clock.advance(901)
	local third = call("basket.claim", userId)
	T.check("tersedia lagi setelah 901 detik", third.ok == true, third.result)
	Clock.advance(-901) -- pulihkan offset jam global agar suite lain tidak terganggu

	-- distribusi 5000 undian (murni)
	local rng = RNG.new(2024)
	local counts = { cash = 0, speed = 0, growth = 0, luck = 0 }
	for _ = 1, 5000 do
		counts[BasketRoll.roll(rng)] += 1
	end
	for _, reward in EconomyConfig.basket.rewards do
		T.check(
			"distribusi " .. reward.kind,
			math.abs(counts[reward.kind] / 5000 - reward.weight / 100) <= 0.03,
			counts[reward.kind]
		)
	end

	-- efek tiap jenis hadiah (klaim berulang dengan mereset cooldown)
	local seen = {}
	local income = call("income.compute", userId)
	for _ = 1, 300 do
		data = DataService.getByUserId(userId)
		data.freeBasketAt = 0
		local cash0, now = data.cash, Clock.now()
		local r = call("basket.claim", userId)
		data = DataService.getByUserId(userId)
		if r.ok and not seen[r.result] then
			seen[r.result] = true
			if r.result == "cash" then
				local expected = math.max(50, income * 180)
				local gained = data.cash - cash0
				T.check(
					"hadiah cash = 3 menit income",
					gained >= expected - 1e-6 and gained <= expected + 20,
					gained
				)
			elseif r.result == "speed" then
				T.check("speed2xUntil terisi", data.boosts.speed2xUntil >= now + 295)
			elseif r.result == "growth" then
				T.check("growth2xUntil terisi", data.boosts.growth2xUntil >= now + 295)
			elseif r.result == "luck" then
				T.check("lucky2xUntil terisi", data.boosts.lucky2xUntil >= now + 595)
				T.check("luck provider x2", call("basket.luck", userId) == 2)
			end
		end
		if seen.cash and seen.speed and seen.growth and seen.luck then
			break
		end
	end
	T.check(
		"keempat jenis hadiah teramati",
		seen.cash and seen.speed and seen.growth and seen.luck,
		"cash/speed/growth/luck"
	)

	data = DataService.getByUserId(userId)
	data.boosts.lucky2xUntil = 0
	T.check("luck kembali x1 setelah habis", call("basket.luck", userId) == 1)

	DataService.wipe(userId)
	T.wait(1.2)
end
