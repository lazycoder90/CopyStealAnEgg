--!nonstrict
-- Skenario uji leaderstats, papan peringkat (jalur fallback), dan Friend Boost.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Leaderboard")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local LeaderboardMath = require(Shared.Logic.LeaderboardMath)
local NumberFormat = require(Shared.Logic.NumberFormat)

local DataService = require(Server.Services.DataService)
local SpeedService = require(Server.Services.SpeedService)
local CurrencyService = require(Server.Services.CurrencyService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge
	local cfg = EconomyConfig.leaderboard
	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		if not r.ok then
			T.check("hook " .. name, false, r.error)
		end
		return r.result
	end

	DataService.wipe(userId)
	T.wait(1.2)

	-- ===== leaderstats =====
	local petUid = call("pets.give", userId, "pebble_chick", 1.2)
	call("pets.equip", userId, petUid)
	CurrencyService.set(userId, "speedBase", 1234)
	T.wait(2.6)
	local folder = T.player:FindFirstChild(cfg.leaderstatsName)
	T.check("folder leaderstats ada", folder ~= nil)
	local speedValue = folder and folder:FindFirstChild(cfg.statSpeed)
	local moneyValue = folder and folder:FindFirstChild(cfg.statMoney)
	T.check("StringValue Speed ada", speedValue ~= nil and speedValue:IsA("StringValue"))
	T.check("StringValue Money/s ada", moneyValue ~= nil and moneyValue:IsA("StringValue"))
	if speedValue and moneyValue then
		local expectSpeed = NumberFormat.fmt(SpeedService.getEffectiveSpeed(userId))
		T.check("Speed terformat", speedValue.Value == expectSpeed, speedValue.Value)
		T.check("Speed 1.23K", speedValue.Value == "1.23K", speedValue.Value)
		T.check("Money/s terformat", moneyValue.Value == "$3/s", moneyValue.Value)
	end

	-- ===== peringkat bot (jalur fallback) =====
	for id = -1, -3, -1 do
		call("bot.spawn", id)
	end
	T.wait(0.3)
	-- tanpa yield antara set dan refresh agar tick income tidak menimpa nilai bot
	DataService.getByUserId(-1).lastIncomePerSec = 900
	DataService.getByUserId(-2).lastIncomePerSec = 50
	DataService.getByUserId(-3).lastIncomePerSec = 7000
	DataService.getByUserId(-1).trophies = 5
	DataService.getByUserId(-2).trophies = 30
	DataService.getByUserId(-3).trophies = 1
	local mode = call("leaderboard.refresh", true)
	T.check("mode fallback saat dipaksa", mode == "fallback", mode)
	local money = call("leaderboard.rows", "money")
	T.check("papan money maks 10 baris", #money >= 4 and #money <= cfg.rows, #money)
	T.check("money #1 = bot -3", money[1] and money[1].userId == -3, money[1] and money[1].userId)
	T.check("money #2 = bot -1", money[2] and money[2].userId == -1)
	T.check("money #3 = bot -2", money[3] and money[3].userId == -2)
	T.check("money #4 = pemain", money[4] and money[4].userId == userId)
	T.check(
		"money berurutan menurun",
		money[1].value >= money[2].value and money[2].value >= money[3].value
	)
	T.check("teks money terformat", money[1].text == "$7K/s", money[1].text)
	T.check("rank terisi", money[1].rank == 1 and money[2].rank == 2)
	local trophy = call("leaderboard.rows", "trophy")
	T.check(
		"trophy #1 = bot -2",
		trophy[1] and trophy[1].userId == -2,
		trophy[1] and trophy[1].userId
	)
	T.check("papan fisik ada", workspace:FindFirstChild(cfg.moneyBoardName, true) ~= nil)
	T.check("papan trophy ada", workspace:FindFirstChild(cfg.trophyBoardName, true) ~= nil)

	local back = LeaderboardMath.decode(LeaderboardMath.encode(123456.789))
	T.check(
		"decode(encode(x)) relatif < 1e-6",
		math.abs(back - 123456.789) / 123456.789 < 1e-6,
		back
	)

	-- ===== Friend Boost: bot tidak pernah dihitung =====
	call("friend.recompute")
	local info = call("friend.info", userId)
	T.check("bot tidak dihitung sebagai teman", info.friends == 0 and info.boost == 0, info.friends)
	local income = call("income.compute", userId)
	T.check("income tanpa bonus teman", math.abs(income - 3) < 1e-6, income)
	T.check("cap +50% (5 teman)", math.abs(EconomyConfig.friendBoost(5) - 0.5) < 1e-9)
	T.check("cap +50% (12 teman)", math.abs(EconomyConfig.friendBoost(12) - 0.5) < 1e-9)

	call("bot.removeAll")
	DataService.wipe(userId)
	T.wait(1.2)
end
