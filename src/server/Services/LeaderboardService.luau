--!nonstrict
-- LeaderboardService: (a) leaderstats Speed dan Money/s per pemain nyata (StringValue),
-- (b) dua papan fisik di dinding belakang hub (Money/s dan Trophies) dari OrderedDataStore.
-- Bila DataStore tidak tersedia (Studio tanpa akses API) papan memeringkat pemain yang ADA di
-- server saat ini (termasuk bot, agar bisa diuji). Semua panggilan DataStore: pcall + backoff.
-- Tidak pernah memblokir Init/Start (loop memakai task.spawn dan waktu nyata).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Layout = require(Shared.Config.Layout)
local LeaderboardMath = require(Shared.Logic.LeaderboardMath)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local cfg = EconomyConfig.leaderboard

local KINDS = {
	money = {
		store = cfg.moneyStore,
		title = cfg.moneyTitle,
		boardName = cfg.moneyBoardName,
		layout = Layout.hubStalls.boardMoney,
		value = function(data)
			return data.lastIncomePerSec or 0
		end,
		format = NumberFormat.fmtRate,
	},
	trophy = {
		store = cfg.trophyStore,
		title = cfg.trophyTitle,
		boardName = cfg.trophyBoardName,
		layout = Layout.hubStalls.boardTrophy,
		value = function(data)
			return data.trophies or 0
		end,
		format = NumberFormat.fmt,
	},
}
local KIND_ORDER = { "money", "trophy" }

local displayed = { money = {}, trophy = {} } -- baris yang sedang tampil
local boardRows = {} -- [kind] = { {rank, name, value}: TextLabel }
local stores = {} -- [kind] = OrderedDataStore
local lastWritten = {} -- [userId] = { money = n, trophy = n }
local nameCache = {} -- [userId] = string
local statValues = {} -- [userId] = { speed = StringValue, money = StringValue }
local mode = "fallback"
local refreshing = false

-- ===== Gerbang DataStore: pcall + backoff + menyerah sementara =====
local failures = 0
local blockedUntil = 0
local episodeWarned = false

local function callStore(fn)
	if os.clock() < blockedUntil then
		return false, "diblokir"
	end
	local ok, result = pcall(fn)
	if ok then
		failures = 0
		episodeWarned = false
		return true, result
	end
	failures += 1
	if failures > #cfg.backoff then
		failures = 0
		blockedUntil = os.clock() + cfg.giveUpSeconds
	else
		blockedUntil = os.clock() + cfg.backoff[failures]
	end
	if not episodeWarned and not RunService:IsStudio() then
		episodeWarned = true
		warn(`[LeaderboardService] DataStore gagal: {result}`)
	end
	return false, result
end

local function getStore(kind: string)
	if stores[kind] then
		return stores[kind]
	end
	local ok, store = callStore(function()
		return DataStoreService:GetOrderedDataStore(KINDS[kind].store)
	end)
	if ok then
		stores[kind] = store
		return store
	end
	return nil
end

-- ===== Nama =====
local function nameFor(userId: number): string
	if Actors.getPlayer(userId) or Actors.isBot(userId) then
		return Actors.getName(userId)
	end
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and type(name) == "string" then name else `User{userId}`
	return nameCache[userId]
end

-- ===== Papan fisik =====
local function buildBoard(kind: string)
	local def = KINDS[kind]
	local parent = workspace:FindFirstChild(Types.Names.Map) or workspace
	local part = Instance.new("Part")
	part.Name = def.boardName
	part.Size = Vector3.new(28, 22, 1)
	part.Position = Vector3.new(def.layout.x, cfg.boardY, def.layout.z)
	part.Anchored = true
	part.Color = Color3.fromRGB(86, 52, 28)
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Back -- sisi +Z menghadap pemain
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(560, 440)
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 244, 222)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 56)
	title.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	title.BorderSizePixel = 0
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 34
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(86, 52, 28)
	title.Text = def.title
	title.Parent = bg

	local rows = {}
	for i = 1, cfg.rows do
		local y = 62 + (i - 1) * 37
		local function label(name, x, w, align)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.Position = UDim2.fromOffset(x, y)
			l.Size = UDim2.fromOffset(w, 34)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamMedium
			l.TextSize = 24
			l.TextColor3 = Color3.fromRGB(86, 52, 28)
			l.TextXAlignment = align
			l.Text = ""
			l.Parent = bg
			return l
		end
		rows[i] = {
			rank = label(`Rank{i}`, 14, 60, Enum.TextXAlignment.Left),
			name = label(`Name{i}`, 80, 260, Enum.TextXAlignment.Left),
			value = label(`Value{i}`, 340, 206, Enum.TextXAlignment.Right),
		}
	end
	boardRows[kind] = rows
	part.Parent = parent
end

local function render(kind: string)
	local rows = boardRows[kind]
	if not rows then
		return
	end
	for i = 1, cfg.rows do
		local row, item = rows[i], displayed[kind][i]
		row.rank.Text = if item then `#{item.rank}` else ""
		row.name.Text = if item then item.name else ""
		row.value.Text = if item then item.text else ""
	end
end

local function setDisplayed(kind: string, entries)
	local def = KINDS[kind]
	local ranked = LeaderboardMath.rank(entries, cfg.rows)
	local list = {}
	for i, entry in ranked do
		table.insert(list, {
			rank = i,
			userId = entry.userId,
			name = nameFor(entry.userId),
			value = entry.value,
			text = def.format(entry.value),
		})
	end
	displayed[kind] = list
	render(kind)
end

local function localEntries(kind: string)
	local def = KINDS[kind]
	local entries = {}
	for _, item in DataService.all() do
		table.insert(entries, { userId = item.userId, value = def.value(item.data) })
	end
	return entries
end

local function storeEntries(kind: string)
	local store = getStore(kind)
	if not store then
		return nil
	end
	local ok, page = callStore(function()
		return store:GetSortedAsync(false, cfg.rows):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local entries = {}
	for _, item in page do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { userId = userId, value = LeaderboardMath.decode(item.value) })
		end
	end
	return entries
end

-- forceLocal: paksa peringkat pemain di server (dipakai uji). Boleh yield (DataStore, nama).
function LeaderboardService.refresh(forceLocal: boolean?)
	while refreshing do
		task.wait()
	end
	refreshing = true
	for _, kind in KIND_ORDER do
		local entries = if forceLocal then nil else storeEntries(kind)
		if entries then
			mode = "datastore"
		else
			mode = "fallback"
			entries = localEntries(kind)
		end
		setDisplayed(kind, entries)
	end
	refreshing = false
end

function LeaderboardService.rows(kind: string)
	local out = {}
	for _, item in displayed[kind] or {} do
		table.insert(out, table.clone(item))
	end
	return out
end

-- Tulis nilai pemain nyata yang berubah >= 1% (dipanggil tiap 120 detik).
local function writeAll()
	for _, entry in DataService.all() do
		if entry.player then
			local record = lastWritten[entry.userId]
			if not record then
				record = {}
				lastWritten[entry.userId] = record
			end
			for _, kind in KIND_ORDER do
				local value = KINDS[kind].value(entry.data)
				if LeaderboardMath.shouldWrite(record[kind], value, cfg.minChange) then
					local store = getStore(kind)
					if store then
						local ok = callStore(function()
							store:SetAsync(`{entry.userId}`, LeaderboardMath.encode(value))
						end)
						if ok then
							record[kind] = value
						end
					end
				end
			end
		end
	end
end

-- ===== leaderstats =====
local function ensureStats(userId: number)
	local player = Actors.getPlayer(userId)
	if not player then
		return nil
	end
	local record = statValues[userId]
	if record and record.speed.Parent and record.money.Parent then
		return record
	end
	local folder = player:FindFirstChild(cfg.leaderstatsName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = cfg.leaderstatsName
		folder.Parent = player
	end
	local function value(name: string)
		local v = folder:FindFirstChild(name)
		if not v then
			v = Instance.new("StringValue")
			v.Name = name
			v.Parent = folder
		end
		return v
	end
	record = { speed = value(cfg.statSpeed), money = value(cfg.statMoney) }
	statValues[userId] = record
	return record
end

local function effectiveSpeed(userId: number, data): number
	local ok, result = pcall(function()
		local SpeedService = require(script.Parent.SpeedService)
		return SpeedService.getEffectiveSpeed(userId)
	end)
	if ok and type(result) == "number" then
		return result
	end
	return data.speedBase or 0
end

local function updateStats(userId: number)
	local data = DataService.getByUserId(userId)
	local record = ensureStats(userId)
	if not (data and record) then
		return
	end
	record.speed.Value = NumberFormat.fmt(effectiveSpeed(userId, data))
	record.money.Value = NumberFormat.fmtRate(data.lastIncomePerSec or 0)
end

function LeaderboardService.Init()
	buildBoard("money")
	buildBoard("trophy")

	PlayerLifecycle.onJoin("LeaderboardService", 100, function(ctx)
		if ctx.player then
			updateStats(ctx.userId)
		end
	end)
	PlayerLifecycle.onLeaving("LeaderboardService", 100, function(ctx)
		statValues[ctx.userId] = nil
		lastWritten[ctx.userId] = nil
		local player = Actors.getPlayer(ctx.userId)
		local folder = player and player:FindFirstChild(cfg.leaderstatsName)
		if folder then
			folder:Destroy()
		end
	end)

	TestBridge.register("leaderboard.rows", LeaderboardService.rows)
	TestBridge.register("leaderboard.refresh", function(forceLocal)
		LeaderboardService.refresh(forceLocal == true)
		return mode
	end)
	TestBridge.register("leaderboard.mode", function()
		return mode
	end)
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			task.wait(cfg.statInterval)
			for _, entry in DataService.all() do
				if entry.player then
					updateStats(entry.userId)
				end
			end
		end
	end)
	task.spawn(function()
		task.wait(3)
		while true do
			LeaderboardService.refresh()
			task.wait(cfg.readInterval)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(cfg.writeInterval)
			writeAll()
		end
	end)
end

return LeaderboardService
