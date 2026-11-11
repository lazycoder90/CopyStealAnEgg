--!nonstrict
-- Billboard info untuk telur dunia dan telur placed (nama, $/s, kg, status tumbuh) + Highlight saat Ready.
-- Teks hanya diperbarui saat attribute berubah.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ModelFactory = require(Shared.ModelFactory)
local Creatures = require(Shared.Config.Creatures)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local EggVisualController = {}

local Attr = Types.Attr
local Tags = Types.Tags

local tracked = {} -- model -> Maid

local function line(name: string, order: number, size: number, color: Color3)
	return UIBuilder.create("TextLabel", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 4),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = size,
		TextColor3 = color,
		Text = "",
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
end

local function setup(model: Model, placed: boolean, maid)
	local body = model.PrimaryPart or model:WaitForChild("Body", 15)
	if not body or not body:IsA("BasePart") or tracked[model] ~= maid then
		return
	end
	local grand = model:GetAttribute(Attr.IsGrand) == true
	local scale = grand and 1.3 or 1
	local textSize = math.floor(18 * scale)

	local gui = UIBuilder.create("BillboardGui", {
		Name = "EggInfo",
		Adornee = body,
		AlwaysOnTop = false,
		MaxDistance = 45,
		Size = UDim2.fromOffset(180 * scale, (textSize + 4) * 4),
		LightInfluence = 0,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		},
	})
	local nameLabel = line("Name", 1, textSize, Theme.Colors.White)
	local incomeLabel = line("Income", 2, textSize - 2, Theme.Colors.Mint)
	local kgLabel = line("Kg", 3, textSize - 4, Theme.Colors.Cream)
	local statusLabel = line("Status", 4, textSize - 2, Theme.Colors.Yolk)
	statusLabel.Visible = placed
	nameLabel.Parent = gui
	incomeLabel.Parent = gui
	kgLabel.Parent = gui
	statusLabel.Parent = gui
	gui.Parent = body
	maid:Give(gui)

	local highlight
	if placed then
		highlight = UIBuilder.create("Highlight", {
			Name = "ReadyGlow",
			Adornee = model,
			FillTransparency = 1,
			OutlineColor = Theme.Colors.Yolk,
			OutlineTransparency = 0,
			Enabled = false,
		})
		highlight.Parent = model
		maid:Give(highlight)
	end

	local function refresh()
		local speciesId = model:GetAttribute(Attr.SpeciesId)
		local ok, creature = pcall(Creatures.get, speciesId)
		nameLabel.Text = ok and creature.name or "Egg"
		local rarity = model:GetAttribute(Attr.Rarity) or (ok and creature.rarity) or 1
		nameLabel.TextColor3 = ModelFactory.rarityColor(rarity)
		incomeLabel.Text = NumberFormat.fmtRate(model:GetAttribute(Attr.Income) or 0)
		kgLabel.Text = string.format("%s kg", NumberFormat.fmt(model:GetAttribute(Attr.Kg) or 0))
		if placed then
			local ready = model:GetAttribute(Attr.Ready) == true
			if ready then
				statusLabel.Text = "Egg Ready!"
			else
				statusLabel.Text = NumberFormat.fmtTime(model:GetAttribute(Attr.GrowRemaining) or 0)
			end
			highlight.Enabled = ready
		end
	end

	local function refreshOffset()
		gui.StudsOffset = Vector3.new(0, body.Size.Y / 2 + 1.5 * scale, 0)
	end

	for _, attrName in
		{ Attr.SpeciesId, Attr.Rarity, Attr.Income, Attr.Kg, Attr.Ready, Attr.GrowRemaining }
	do
		maid:Give(model:GetAttributeChangedSignal(attrName):Connect(refresh))
	end
	maid:Give(body:GetPropertyChangedSignal("Size"):Connect(refreshOffset))
	refresh()
	refreshOffset()
end

local function track(model: Instance, placed: boolean)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local maid = Maid.new()
	tracked[model] = maid
	task.spawn(setup, model, placed, maid)
end

local function untrack(model: Instance)
	local maid = tracked[model]
	if maid then
		tracked[model] = nil
		maid:Clean()
	end
end

local function watchTag(tag: string, placed: boolean)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		track(model, placed)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	for _, model in CollectionService:GetTagged(tag) do
		track(model, placed)
	end
end

function EggVisualController.Start()
	watchTag(Tags.WorldEgg, false)
	watchTag(Tags.PlacedEgg, true)
end

return EggVisualController
