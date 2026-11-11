--!nonstrict
-- IncomeService: pendapatan pasif dari pet aktif (tick 1 Hz waktu-game).
-- income/s = sum(petIncome aktif) * (1 + sum(bonus aditif)) * prod(pengali)
-- Bonus aditif (teman, companion, Index) dan pengali (gamepass 2x) didaftarkan service lain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetMath = require(Shared.Logic.PetMath)
local Net = require(Shared.Net.Net)

local Systems = script.Parent.Parent.Systems
local Clock = require(Systems.Clock)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local IncomeService = {}

local bonuses = {} -- [name] = function(userId) -> number (aditif, mis. 0.1 = +10%)
local multipliers = {} -- [name] = function(userId) -> number (pengali)
local popupAccumulator = {} -- [userId] = cash terkumpul sejak popup terakhir
local ticks = 0

local POPUP_EVERY = 2 -- detik

function IncomeService.addBonus(name: string, fn: (number) -> number)
	bonuses[name] = fn
end

function IncomeService.addMultiplier(name: string, fn: (number) -> number)
	multipliers[name] = fn
end

function IncomeService.compute(userId: number, data): number
	local sum = 0
	for _, pet in data.pets do
		if pet.eq then
			sum += PetMath.petIncome(pet.id, pet.kg, pet.muts)
		end
	end
	if sum <= 0 then
		return 0
	end
	local bonus = 1
	for _, fn in bonuses do
		bonus += fn(userId)
	end
	local mult = 1
	for _, fn in multipliers do
		mult *= fn(userId)
	end
	return sum * bonus * mult
end

local function tick(dt: number)
	ticks += 1
	for _, entry in DataService.all() do
		local userId, data = entry.userId, entry.data
		local income = IncomeService.compute(userId, data)

		local previous = data.lastIncomePerSec or 0
		if income ~= previous then
			data.lastIncomePerSec = income
			StateReplicator.set(userId, "lastIncomePerSec", income)
		end
		if income > (data.peakIncome or 0) then
			data.peakIncome = income
		end

		if income > 0 then
			local earned = income * dt
			CurrencyService.add(userId, "cash", earned)
			popupAccumulator[userId] = (popupAccumulator[userId] or 0) + earned
		end
	end

	if ticks % POPUP_EVERY == 0 then
		for userId, amount in popupAccumulator do
			popupAccumulator[userId] = nil
			local player = Players:GetPlayerByUserId(userId)
			if player and amount > 0 then
				Net.fire("IncomePopup", player, amount)
			end
		end
	end
end

function IncomeService.Init()
	TestBridge.register("income.compute", function(userId)
		local data = DataService.getByUserId(userId)
		return data and IncomeService.compute(userId, data)
	end)
end

function IncomeService.Start()
	Clock.every1Hz(tick)
end

return IncomeService
