--!nonstrict
-- MonetizationService: gamepass (efek lewat provider service lain), ProcessReceipt idempoten untuk
-- developer product, dan remote Skip Growth / Grow All. Semua id Robux di config bernilai 0 sampai
-- pemilik membuatnya: id 0 tidak pernah didaftarkan, tidak pernah dipanggil Prompt*, tombol "Coming soon".
-- Hook TestBridge: monetization.setOwned(userId, key, bool|nil), monetization.registerProduct(id, kind, arg),
-- monetization.unregisterProduct(id), monetization.process(info), monetization.requestSkip(userId, uid),
-- monetization.requestGrowAll(userId), monetization.promptCount(), monetization.ownedMultipliers(userId).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Progression = require(Shared.Config.Progression)
local MonetizationMath = require(Shared.Logic.MonetizationMath)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local Clock = require(Systems.Clock)
local GameEvents = require(Systems.GameEvents)
local InvariantChecker = require(Systems.InvariantChecker)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DefenseService = require(script.Parent.DefenseService)
local GrowthService = require(script.Parent.GrowthService)
local HatchService = require(script.Parent.HatchService)
local IncomeService = require(script.Parent.IncomeService)
local OfflineEarningsService = require(script.Parent.OfflineEarningsService)
local SpeedService = require(script.Parent.SpeedService)
local StateReplicator = require(script.Parent.StateReplicator)
local TrailService = require(script.Parent.TrailService)
local WheelService = require(script.Parent.WheelService)

local MonetizationService = {}

local NOT_AVAILABLE = "Robux purchases are not available yet"
local RECEIPT_MAX_KEYS = 120

local ownedCache = {} -- [userId] = { [passKey] = true } hasil UserOwnsGamePassAsync
local overrides = {} -- [userId] = { [passKey] = bool } (hanya uji)
local products = {} -- [productId] = { kind, arg, key }
local promptCount = 0 -- jumlah panggilan Prompt* (uji: harus 0 untuk id 0)
local passByKey = {}
local passById = {}

for _, pass in MonetizationConfig.gamepasses do
	passByKey[pass.key] = pass
	if pass.id ~= 0 then
		passById[pass.id] = pass
	end
end

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

-- ===== Kepemilikan gamepass =====

local function isOwned(userId: number, key: string): boolean
	local override = overrides[userId] and overrides[userId][key]
	if override ~= nil then
		return override
	end
	local cache = ownedCache[userId]
	return cache ~= nil and cache[key] == true
end

function MonetizationService.owns(userId: number, key: string): boolean
	return isOwned(userId, key)
end

-- Publikasikan kepemilikan runtime (bukan bagian profil) ke klien.
local function publishOwned(userId: number)
	for _, pass in MonetizationConfig.gamepasses do
		StateReplicator.set(userId, `ownedPasses.{pass.key}`, isOwned(userId, pass.key))
	end
end

-- +3 slot equip sekali seumur profil (data.passes.equip3). Tanpa yield.
local function applyEquip3(userId: number)
	local data = DataService.getByUserId(userId)
	if not data or data.passes.equip3 == true or not isOwned(userId, "equip3") then
		return false
	end
	data.equipSlots = math.min(data.equipSlots + 3, Progression.maxEquipSlots)
	data.passes.equip3 = true
	StateReplicator.set(userId, "equipSlots", data.equipSlots)
	StateReplicator.set(userId, "passes.equip3", true)
	return true
end

-- Tanya Roblox (yield). id 0 dilewati; galat jaringan dianggap belum memiliki.
local function refreshOwnership(userId: number)
	local cache = {}
	for _, pass in MonetizationConfig.gamepasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(userId, pass.id)
			end)
			if ok and owns == true then
				cache[pass.key] = true
			end
		end
	end
	if not DataService.getByUserId(userId) then
		return
	end
	ownedCache[userId] = cache
	publishOwned(userId)
	applyEquip3(userId)
end

-- ===== Pemberian produk =====

local function incomeOf(userId: number, data): number
	local income = IncomeService.compute(userId, data)
	if income <= 0 then
		income = data.lastIncomePerSec or 0
	end
	return income
end

local function compensate(userId: number, data, message: string)
	CurrencyService.add(userId, "cash", MonetizationMath.compensationCash(incomeOf(userId, data)))
	notify(userId, message, "success")
end

local function skippable(userId: number, uid: string, data): boolean
	local egg = data.eggs[uid]
	return egg ~= nil
		and egg.loc == "placed"
		and not GrowthService.isFrozen(userId, uid)
		and egg.progress < egg.growTotal
end

local function finishEgg(userId: number, uid: string, data)
	local egg = data.eggs[uid]
	egg.progress = egg.growTotal
	StateReplicator.set(userId, `eggs.{uid}.progress`, egg.progress)
	GrowthService.ensureModel(userId, uid)
end

local function clearPending(userId: number, data)
	data.pendingSkip = {}
	StateReplicator.set(userId, "pendingSkip", {})
end

-- tier = tingkat produk yang DIBELI. Telur hanya boleh di-skip jika tier-nya (menurut sisa waktu) tidak
-- lebih tinggi dari produk yang dibayar, sehingga produk murah tidak bisa menyelesaikan telur "mahal".
local function grantSkip(userId: number, data, tier: any): boolean
	local maxTier = tonumber(tier) or math.huge
	local function eligible(uid: string): boolean
		if not skippable(userId, uid, data) then
			return false
		end
		local egg = data.eggs[uid]
		return MonetizationMath.skipTier(egg.growTotal - egg.progress) <= maxTier
	end

	local pending = data.pendingSkip
	local target = pending and pending.uid
	if not (target and eligible(target)) then
		target = nil
		local best = -1
		for uid, egg in data.eggs do
			if eligible(uid) and egg.growTotal - egg.progress > best then
				best = egg.growTotal - egg.progress
				target = uid
			end
		end
	end
	if target then
		finishEgg(userId, target, data)
		notify(userId, "Egg finished growing!", "success")
	else
		compensate(userId, data, "No egg to skip, so you got a cash bonus instead!")
	end
	clearPending(userId, data)
	return true
end

local function grantGrowAll(userId: number, data): boolean
	local any = false
	for uid in data.eggs do
		if skippable(userId, uid, data) then
			finishEgg(userId, uid, data)
			any = true
		end
	end
	if any then
		notify(userId, "All eggs finished growing!", "success")
	else
		compensate(userId, data, "No eggs were growing, so you got a cash bonus instead!")
	end
	clearPending(userId, data)
	return true
end

local function grantPotion(userId: number, data, which: string): boolean
	local field = if which == "speed"
		then "speed2x"
		elseif which == "luck" then "lucky2x"
		elseif which == "growth" then "growth2x"
		else nil
	if not field then
		return false
	end
	field ..= "Until"
	local seconds = MonetizationConfig.potionSeconds[which]
	data.boosts[field] = math.max(data.boosts[field] or 0, Clock.now() + seconds)
	StateReplicator.set(userId, `boosts.{field}`, data.boosts[field])
	notify(userId, `{which} potion active!`, "success")
	return true
end

local function grantShield(userId: number, data): boolean
	-- DefenseService tidak punya varian paksa: reset cooldown lalu aktifkan (durasi standar Shield).
	if DefenseService.getShieldRemaining(userId) > 0 then
		DefenseService.endShield(userId)
	end
	data.shieldReadyAt = 0
	local ok = DefenseService.activateShield(userId)
	return ok == true
end

local function grant(userId: number, data, kind: string, arg): boolean
	if kind == "skipGrowth" then
		return grantSkip(userId, data, arg)
	elseif kind == "growAll" then
		return grantGrowAll(userId, data)
	elseif kind == "wheel" then
		if not WheelService.grantLevel(userId) then
			compensate(userId, data, "Your wheel is maxed, so you got a cash bonus instead!")
		end
		return true
	elseif kind == "cash" then
		local amount = MonetizationMath.cashPackAmount(incomeOf(userId, data), arg)
		CurrencyService.add(userId, "cash", amount)
		notify(userId, "Cash pack delivered!", "success")
		return true
	elseif kind == "shield" then
		return grantShield(userId, data)
	elseif kind == "potion" then
		return grantPotion(userId, data, arg)
	elseif kind == "trail" then
		return TrailService.grant(userId, arg)
	end
	return false
end

-- ===== ProcessReceipt =====

-- info = { PlayerId, PurchaseId, ProductId }. Idempoten: PurchaseId yang sama tidak diberikan dua kali.
function MonetizationService.processReceipt(info): Enum.ProductPurchaseDecision
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local userId = info.PlayerId
	local data = DataService.getByUserId(userId)
	if not data then
		return notYet
	end
	local product = products[info.ProductId]
	if not product then
		return notYet
	end
	local receiptKey = tostring(info.PurchaseId)
	if data.receipts[receiptKey] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Beri lalu catat dalam satu langkah sinkron; gagal memberi = jangan catat.
	if not grant(userId, data, product.kind, product.arg) then
		return notYet
	end
	data.receipts[receiptKey] = Clock.now()
	MonetizationMath.pruneReceipts(data.receipts, MonetizationConfig.receiptKeep)
	GameEvents.PurchaseGranted:Fire({ userId = userId, kind = product.kind, id = product.key })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function safeReceipt(info)
	local ok, result = pcall(MonetizationService.processReceipt, info)
	if not ok then
		warn("[MonetizationService] ProcessReceipt gagal:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return result
end

-- ===== Remote Skip Growth / Grow All =====

local function prompt(player: Player, productId: number)
	promptCount += 1
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[MonetizationService] PromptProductPurchase gagal:", err)
	end
end

local function productIdOf(key: string): number
	local product = MonetizationConfig.getProduct(key)
	return product and product.id or 0
end

-- Mengembalikan status string untuk uji: "prompted" | "unavailable" | "invalid".
function MonetizationService.requestSkip(player: Player, eggUid: string): string
	local userId = player.UserId
	local data = DataService.getByUserId(userId)
	if not (data and skippable(userId, eggUid, data)) then
		notify(userId, "That egg can't be skipped right now.", "error")
		return "invalid"
	end
	local egg = data.eggs[eggUid]
	local tier = MonetizationMath.skipTier(egg.growTotal - egg.progress)
	local productId = productIdOf(`skip{tier}`)
	if productId == 0 then
		clearPending(userId, data)
		notify(userId, NOT_AVAILABLE, "error")
		return "unavailable"
	end
	data.pendingSkip = { uid = eggUid, at = Clock.now() }
	StateReplicator.set(userId, "pendingSkip", data.pendingSkip)
	prompt(player, productId)
	return "prompted"
end

function MonetizationService.requestGrowAll(player: Player): string
	local userId = player.UserId
	local data = DataService.getByUserId(userId)
	if not data then
		return "invalid"
	end
	local any = false
	for uid in data.eggs do
		if skippable(userId, uid, data) then
			any = true
			break
		end
	end
	if not any then
		notify(userId, "No eggs are growing.", "error")
		return "invalid"
	end
	local productId = productIdOf("growAll")
	if productId == 0 then
		notify(userId, NOT_AVAILABLE, "error")
		return "unavailable"
	end
	prompt(player, productId)
	return "prompted"
end

-- ===== Registrasi =====

local function registerProduct(id: number, kind: string, arg, key: string?)
	if type(id) ~= "number" or id == 0 then
		return false
	end
	products[id] = { kind = kind, arg = arg, key = key or kind }
	return true
end

local function checkInvariants(entry)
	local out = {}
	local count = 0
	for key in entry.data.receipts do
		count += 1
		if type(key) ~= "string" then
			table.insert(out, `kunci receipts bukan string: {tostring(key)}`)
		end
	end
	if count > RECEIPT_MAX_KEYS then
		table.insert(out, `receipts terlalu banyak: {count}`)
	end
	local pending = entry.data.pendingSkip
	if type(pending) ~= "table" then
		table.insert(out, "pendingSkip bukan tabel")
	elseif
		next(pending) ~= nil
		and not (type(pending.uid) == "string" and type(pending.at) == "number")
	then
		table.insert(out, "pendingSkip tanpa uid/at")
	end
	return out
end

function MonetizationService.Init()
	-- Efek gamepass dievaluasi lazy dari cache kepemilikan.
	IncomeService.addMultiplier("passMoney2x", function(userId)
		return if isOwned(userId, "money2x") then 2 else 1
	end)
	SpeedService.addMultiplier("passSpeed2x", function(userId)
		return if isOwned(userId, "speed2x") then 2 else 1
	end)
	OfflineEarningsService.addCapMultiplier("passVip", function(userId)
		return if isOwned(userId, "vip") then 2 else 1
	end)
	HatchService.addLuckProvider("passLucky", function(userId)
		return if isOwned(userId, "lucky") then 2 else 1
	end)
	GrowthService.addMultiplierProvider("passFastGrowth", function(userId)
		return if isOwned(userId, "fastGrowth") then 1.5 else 1
	end)

	for _, product in MonetizationConfig.products do
		registerProduct(product.id, product.kind, product.arg, product.key)
	end

	PlayerLifecycle.onJoin("MonetizationService", 100, function(ctx)
		ownedCache[ctx.userId] = nil
		applyEquip3(ctx.userId)
		if ctx.player then
			task.spawn(refreshOwnership, ctx.userId)
		end
	end)
	-- order 1100: setelah snapshot StateReplicator (1000) agar nilai pertama sampai ke klien.
	PlayerLifecycle.onJoin("MonetizationService.replicate", 1100, function(ctx)
		publishOwned(ctx.userId)
	end)
	PlayerLifecycle.onLeaving("MonetizationService", 100, function(ctx)
		ownedCache[ctx.userId] = nil
		overrides[ctx.userId] = nil
	end)

	InvariantChecker.register("Monetization", checkInvariants)

	TestBridge.register("monetization.setOwned", function(userId, key, value)
		if not passByKey[key] then
			return false
		end
		overrides[userId] = overrides[userId] or {}
		overrides[userId][key] = value
		if next(overrides[userId]) == nil then
			overrides[userId] = nil
		end
		publishOwned(userId)
		if key == "equip3" then
			applyEquip3(userId)
		end
		return true
	end)
	TestBridge.register("monetization.registerProduct", function(id, kind, arg)
		-- id uji boleh bukan nol; id 0 tetap ditolak seperti config.
		return registerProduct(id, kind, arg, "test")
	end)
	TestBridge.register("monetization.unregisterProduct", function(id)
		products[id] = nil
		return true
	end)
	TestBridge.register("monetization.hasProduct", function(id)
		return products[id] ~= nil
	end)
	TestBridge.register("monetization.productCount", function()
		local count = 0
		for _ in products do
			count += 1
		end
		return count
	end)
	TestBridge.register("monetization.process", function(info)
		return MonetizationService.processReceipt(info)
			== Enum.ProductPurchaseDecision.PurchaseGranted
	end)
	TestBridge.register("monetization.requestSkip", function(userId, eggUid)
		local player = Actors.getPlayer(userId)
		return player and MonetizationService.requestSkip(player, eggUid)
	end)
	TestBridge.register("monetization.requestGrowAll", function(userId)
		local player = Actors.getPlayer(userId)
		return player and MonetizationService.requestGrowAll(player)
	end)
	TestBridge.register("monetization.promptCount", function()
		return promptCount
	end)
	-- Hasil kali provider yang didaftarkan service ini untuk satu pemain (uji).
	TestBridge.register("monetization.passEffects", function(userId)
		local data = DataService.getByUserId(userId)
		return {
			income = data and IncomeService.compute(userId, data),
			speed = SpeedService.getEffectiveSpeed(userId),
			growth = GrowthService.multiplier(userId),
			luck = isOwned(userId, "lucky") and 2 or 1,
		}
	end)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = safeReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if not (pass and purchased) then
			return
		end
		local userId = player.UserId
		ownedCache[userId] = ownedCache[userId] or {}
		ownedCache[userId][pass.key] = true
		publishOwned(userId)
		applyEquip3(userId)
		notify(userId, `{pass.name} unlocked!`, "success")
		GameEvents.PurchaseGranted:Fire({ userId = userId, kind = "gamepass", id = pass.key })
	end)

	Net.on("RequestSkipGrowth", Check.args(Check.uid), function(player, eggUid)
		MonetizationService.requestSkip(player, eggUid)
	end)
	Net.on("RequestGrowAll", Check.args(), function(player)
		MonetizationService.requestGrowAll(player)
	end)
	Net.on("RequestRewardedAd", Check.args(Check.str(20)), function(player)
		notify(player.UserId, "Not available yet", "error")
	end)

	-- Snapshot StateReplicator dikirim saat ClientReady (handler-nya jalan sesudah ini): terbitkan ulang
	-- kepemilikan runtime sedikit kemudian agar tidak tertimpa snapshot.
	Net.on("ClientReady", Check.args(), function(player)
		local userId = player.UserId
		task.delay(0.5, function()
			if DataService.getByUserId(userId) then
				publishOwned(userId)
			end
		end)
	end)
end

return MonetizationService
