--!nonstrict
-- SellService: jual telur (kantong atau ditaruh, tidak beku) dan pet (tidak aktif, tidak terkunci).
-- Server menghitung ulang semua nilai; uid tidak valid/ganda diabaikan. Kios SELL di hub membuka panel
-- di klien lewat ProximityPromptService (tanpa remote).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Check = require(Shared.Util.Check)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local SellConfig = require(Shared.Config.SellConfig)
local SellMath = require(Shared.Logic.SellMath)
local Types = require(Shared.Types)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local TestBridge = require(Systems.TestBridge)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local PetService = require(script.Parent.PetService)
local StateReplicator = require(script.Parent.StateReplicator)

local Names = Types.Names

local SellService = {}

local function notify(userId: number, message: string, kind: string)
	local player = Actors.getPlayer(userId)
	if player then
		Net.fire("Notify", player, message, kind)
	end
end

-- Menjual item. Mengembalikan ok, jumlah terjual, total uang. Atomik (tanpa yield).
function SellService.sell(userId: number, kind: string, uids: { string }): (boolean, number, number)
	local data = DataService.getByUserId(userId)
	if not data or (kind ~= "eggs" and kind ~= "pets") then
		return false, 0, 0
	end
	local bucket = if kind == "eggs" then data.eggs else data.pets

	-- Tahap 1: pilih item yang sah (abaikan tidak dikenal, ganda, terlindungi).
	local chosen, seen, total = {}, {}, 0
	for i, uid in uids do
		if i > SellConfig.maxPerRequest then
			break
		end
		if type(uid) == "string" and not seen[uid] then
			seen[uid] = true
			local entry = bucket[uid]
			local sellable
			if kind == "eggs" then
				sellable = SellMath.eggSellable(entry, GrowthService.isFrozen(userId, uid))
			else
				sellable = SellMath.petSellable(entry)
			end
			if sellable then
				table.insert(chosen, uid)
				total += SellMath.value(kind, entry)
			end
		end
	end
	if #chosen == 0 then
		notify(userId, "Nothing to sell.", "error")
		return false, 0, 0
	end

	-- Tahap 2: hapus semua, replikasi, lalu tambah uang sekali.
	local removedPet = false
	for _, uid in chosen do
		bucket[uid] = nil
		if kind == "eggs" then
			GrowthService.removeModel(userId, uid)
			StateReplicator.set(userId, `eggs.{uid}`, nil)
		else
			removedPet = true
			StateReplicator.set(userId, `pets.{uid}`, nil)
		end
	end
	if removedPet then
		PetService.refreshPlot(userId)
	end
	CurrencyService.add(userId, "cash", total)

	local count = #chosen
	notify(
		userId,
		`Sold {count} {if count == 1 then "item" else "items"} for {NumberFormat.fmtMoney(total)}`,
		"success"
	)
	return true, count, total
end

local function buildStall()
	local parent = workspace:FindFirstChild(Names.Map) or workspace
	local model = Instance.new("Model")
	model.Name = SellConfig.stallName

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local s = SellConfig.stall
	local base = Vector3.new(s.x, s.y, s.z)
	local wood = Color3.fromRGB(150, 104, 62)
	local red = Color3.fromRGB(205, 52, 44)
	local white = Color3.fromRGB(250, 246, 238)

	local counter = block(
		"Counter",
		Vector3.new(12, 3.5, 4),
		base + Vector3.new(0, 1.75, 0),
		wood,
		Enum.Material.Wood
	)
	block(
		"PostL",
		Vector3.new(1, 10, 1),
		base + Vector3.new(-5.5, 5, -1.5),
		wood,
		Enum.Material.Wood
	)
	block(
		"PostR",
		Vector3.new(1, 10, 1),
		base + Vector3.new(5.5, 5, -1.5),
		wood,
		Enum.Material.Wood
	)

	-- Kanopi belang merah-putih: 7 jalur selebar 2 stud.
	local stripes = 7
	local width = 2
	local roof
	for i = 1, stripes do
		local x = (i - (stripes + 1) / 2) * width
		local part = block(
			`Awning{i}`,
			Vector3.new(width, 1, 7),
			base + Vector3.new(x, 10, -1),
			if i % 2 == 1 then red else white,
			Enum.Material.SmoothPlastic
		)
		if i == (stripes + 1) / 2 then
			roof = part
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 200
	gui.Parent = roof
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = SellConfig.signText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(150, 30, 24)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = SellConfig.promptName
	prompt.ActionText = SellConfig.promptText
	prompt.ObjectText = "Sell Stand"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
end

function SellService.Init()
	buildStall()

	TestBridge.register("sell.sell", function(userId, kind, uids)
		local ok, count, total = SellService.sell(userId, kind, uids)
		return { ok = ok, count = count, total = total }
	end)
end

function SellService.Start()
	Net.on(
		"SellItems",
		Check.args(Check.enum({ "eggs", "pets" }), Check.uidList(SellConfig.maxPerRequest)),
		function(player, kind, uids)
			SellService.sell(player.UserId, kind, uids)
		end
	)
end

return SellService
