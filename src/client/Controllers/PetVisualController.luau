--!nonstrict
-- Merender pet aktif secara lokal: cermin Folder ActivePets tiap plot menjadi model klien yang berjalan
-- acak di dalam lantai plot. Juga menampilkan popup "+$X" saat IncomePopup tiba.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)
local ModelFactory = require(Shared.ModelFactory)
local Creatures = require(Shared.Config.Creatures)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local PetVisualController = {}

local Attr = Types.Attr
local Tags = Types.Tags
local Names = Types.Names

local WALK_SPEED = 4
local BOUNDS_INSET = 6
local player = Players.LocalPlayer

local clientFolder
local plots = {} -- plot Instance -> plotState
local moving = {} -- rec -> true (semua pet yang punya model)
local rng = Random.new()

local pendingAmount = 0
local popupScheduled = false
local anchorPart -- adornee cadangan di tengah plot sendiri

-- ===== Pet =====

local function parseMuts(text)
	local result = {}
	if type(text) == "string" and text ~= "" then
		for part in string.gmatch(text, "[^,]+") do
			table.insert(result, part)
		end
	end
	return result
end

local function pickTarget(rec)
	local half = rec.plotState.half
	local lx = math.max(half.X - BOUNDS_INSET, 0)
	local lz = math.max(half.Z - BOUNDS_INSET, 0)
	return rng:NextNumber(-lx, lx), rng:NextNumber(-lz, lz)
end

local function updateLabels(rec)
	if not rec.nameLabel then
		return
	end
	local folder = rec.folder
	rec.nameLabel.Text = rec.petName or "Pet"
	rec.nameLabel.TextColor3 =
		ModelFactory.rarityColor(folder:GetAttribute(Attr.Rarity) or rec.rarity or 1)
	rec.incomeLabel.Text = NumberFormat.fmtRate(folder:GetAttribute(Attr.Income) or 0)
end

local function destroyModel(rec)
	moving[rec] = nil
	if rec.model then
		rec.model:Destroy()
		rec.model, rec.body, rec.nameLabel, rec.incomeLabel = nil, nil, nil, nil
	end
end

local function buildModel(rec)
	local folder = rec.folder
	local plotState = rec.plotState
	local speciesId = folder:GetAttribute(Attr.SpeciesId)
	if type(speciesId) ~= "string" or not plotState.floor then
		destroyModel(rec)
		return
	end
	local ok, creature = pcall(Creatures.get, speciesId)
	if not ok then
		destroyModel(rec)
		return
	end
	destroyModel(rec)
	local kg = folder:GetAttribute(Attr.Kg) or creature.baseKg
	local muts = parseMuts(folder:GetAttribute(Attr.Muts))
	local model = ModelFactory.makeCreature(creature, kg, muts)
	model.Name = rec.uid
	rec.petName = creature.name
	rec.rarity = creature.rarity
	rec.model = model
	rec.body = model.PrimaryPart
	local height = model:GetExtentsSize().Y
	rec.halfHeight = height / 2

	if not rec.lx then
		rec.lx, rec.lz = pickTarget(rec)
	end
	rec.tx, rec.tz = rec.lx, rec.lz
	rec.pauseUntil = os.clock() + rng:NextNumber(0.2, 2)
	rec.phase = rng:NextNumber(0, 6.28)
	rec.dirX, rec.dirZ = 0, -1

	local gui = UIBuilder.create("BillboardGui", {
		Name = "PetInfo",
		Adornee = rec.body,
		MaxDistance = 60,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Size = UDim2.fromOffset(160, 44),
		StudsOffset = Vector3.new(0, height / 2 + 1.5, 0),
	})
	local function label(name, order, size, color)
		return UIBuilder.create("TextLabel", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, size + 4),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextSize = size,
			TextColor3 = color,
			Text = "",
			Parent = gui,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
			},
		})
	end
	UIBuilder.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = gui,
	})
	rec.nameLabel = label("Name", 1, 17, Theme.Colors.White)
	rec.incomeLabel = label("Income", 2, 15, Theme.Colors.Mint)
	gui.Parent = rec.body
	updateLabels(rec)

	model.Parent = clientFolder
	moving[rec] = true
end

local function removePet(plotState, uid)
	local rec = plotState.pets[uid]
	if rec then
		plotState.pets[uid] = nil
		destroyModel(rec)
		rec.maid:Clean()
	end
end

local function addPet(plotState, folder)
	local uid = folder.Name
	if plotState.pets[uid] then
		return
	end
	local rec = { uid = uid, folder = folder, plotState = plotState, maid = Maid.new() }
	plotState.pets[uid] = rec
	local function rebuild()
		buildModel(rec)
	end
	for _, name in { Attr.SpeciesId, Attr.Kg, Attr.Muts } do
		rec.maid:Give(folder:GetAttributeChangedSignal(name):Connect(rebuild))
	end
	for _, name in { Attr.Income, Attr.Rarity } do
		rec.maid:Give(folder:GetAttributeChangedSignal(name):Connect(function()
			updateLabels(rec)
		end))
	end
	buildModel(rec)
end

-- ===== Plot =====

local function detachFolder(plotState)
	plotState.folderMaid:Clean()
	for uid in plotState.pets do
		removePet(plotState, uid)
	end
	plotState.folder = nil
end

local function attachFolder(plotState, folder)
	if plotState.folder == folder then
		return
	end
	detachFolder(plotState)
	plotState.folder = folder
	local fm = plotState.folderMaid
	fm:Give(folder.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			addPet(plotState, child)
		end
	end))
	fm:Give(folder.ChildRemoved:Connect(function(child)
		removePet(plotState, child.Name)
	end))
	for _, child in folder:GetChildren() do
		if child:IsA("Folder") then
			addPet(plotState, child)
		end
	end
end

local function refreshFloor(plotState)
	local floor = plotState.plot:FindFirstChild(Names.PlotFloor)
	if floor and floor:IsA("BasePart") then
		plotState.floor = floor
		plotState.half = floor.Size * 0.5
		-- Pet yang menunggu lantai dibangun ulang.
		for _, rec in plotState.pets do
			if not rec.model then
				buildModel(rec)
			end
		end
	end
end

local function trackPlot(plot)
	if plots[plot] or not plot:IsA("Model") then
		return
	end
	local plotState = { plot = plot, pets = {}, maid = Maid.new(), folderMaid = Maid.new() }
	plots[plot] = plotState
	local maid = plotState.maid

	local function scan()
		refreshFloor(plotState)
		local folder = plot:FindFirstChild(Names.PlotPets)
		if folder and folder:IsA("Folder") then
			attachFolder(plotState, folder)
		end
	end
	maid:Give(plot.ChildAdded:Connect(function(child)
		if child.Name == Names.PlotFloor or child.Name == Names.PlotPets then
			scan()
		end
	end))
	maid:Give(plot.ChildRemoved:Connect(function(child)
		if child == plotState.folder then
			detachFolder(plotState)
		end
	end))
	scan()
end

local function untrackPlot(plot)
	local plotState = plots[plot]
	if plotState then
		plots[plot] = nil
		detachFolder(plotState)
		plotState.maid:Clean()
	end
end

local function ownPlotState()
	for plot, plotState in plots do
		if plot:GetAttribute(Attr.OwnerUserId) == player.UserId then
			return plotState
		end
	end
	return nil
end

-- ===== Gerak (satu Heartbeat untuk semua pet) =====

local function onHeartbeat(dt)
	local now = os.clock()
	for rec in moving do
		local plotState = rec.plotState
		local floor = plotState.floor
		local model = rec.model
		if floor and model and model.Parent then
			local bob = 0
			if now >= rec.pauseUntil then
				local dx, dz = rec.tx - rec.lx, rec.tz - rec.lz
				local dist = math.sqrt(dx * dx + dz * dz)
				local stepLen = WALK_SPEED * dt
				if dist <= stepLen then
					rec.lx, rec.lz = rec.tx, rec.tz
					rec.pauseUntil = now + rng:NextNumber(1, 4)
					rec.tx, rec.tz = pickTarget(rec)
				else
					rec.dirX, rec.dirZ = dx / dist, dz / dist
					rec.lx += rec.dirX * stepLen
					rec.lz += rec.dirZ * stepLen
					bob = math.abs(math.sin(now * 8 + rec.phase)) * 0.25
				end
			end
			local cf = floor.CFrame
			local pos = cf:PointToWorldSpace(
				Vector3.new(rec.lx, plotState.half.Y + rec.halfHeight + bob, rec.lz)
			)
			local dir = cf:VectorToWorldSpace(Vector3.new(rec.dirX, 0, rec.dirZ))
			model:PivotTo(CFrame.lookAt(pos, pos + dir))
		end
	end
end

-- ===== Popup pendapatan =====

local function spawnPopup(amount)
	local adornee
	local ownState = ownPlotState()
	if ownState then
		local candidates = {}
		for _, rec in ownState.pets do
			if rec.body and rec.body.Parent then
				table.insert(candidates, rec)
			end
		end
		if #candidates > 0 then
			local rec = candidates[rng:NextInteger(1, #candidates)]
			adornee = rec.body
		elseif ownState.floor then
			anchorPart.CFrame = ownState.floor.CFrame * CFrame.new(0, ownState.half.Y + 2, 0)
			adornee = anchorPart
		end
	end
	if not adornee then
		return
	end

	local startOffset = Vector3.new(0, 4, 0)
	local gui = UIBuilder.create("BillboardGui", {
		Name = "IncomePopup",
		Adornee = adornee,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(160, 40),
		StudsOffsetWorldSpace = startOffset,
		MaxDistance = 120,
	})
	local text = UIBuilder.create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 28,
		TextColor3 = Theme.Colors.Mint,
		Text = "+" .. NumberFormat.fmtMoney(amount),
		Parent = gui,
	})
	local stroke = UIBuilder.create("UIStroke", {
		Thickness = 2,
		Color = Theme.Colors.Brown,
		Parent = text,
	})
	gui.Parent = adornee

	local info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = startOffset + Vector3.new(0, 4, 0) })
		:Play()
	TweenService:Create(text, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(1.6, function()
		gui:Destroy()
	end)
end

local function onIncomePopup(amount)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end
	pendingAmount += amount
	if popupScheduled then
		return
	end
	popupScheduled = true
	-- Gabungkan popup yang datang berdekatan.
	task.delay(0.25, function()
		popupScheduled = false
		local total = pendingAmount
		pendingAmount = 0
		spawnPopup(total)
	end)
end

function PetVisualController.Start()
	clientFolder = Instance.new("Folder")
	clientFolder.Name = "ClientPets"
	clientFolder.Parent = workspace

	anchorPart = Instance.new("Part")
	anchorPart.Name = "PopupAnchor"
	anchorPart.Size = Vector3.one
	anchorPart.Transparency = 1
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Parent = clientFolder

	CollectionService:GetInstanceAddedSignal(Tags.Coop):Connect(trackPlot)
	CollectionService:GetInstanceRemovedSignal(Tags.Coop):Connect(untrackPlot)
	for _, plot in CollectionService:GetTagged(Tags.Coop) do
		trackPlot(plot)
	end

	RunService.Heartbeat:Connect(onHeartbeat)
	Net.connect("IncomePopup", onIncomePopup)
end

return PetVisualController
