--!nonstrict
-- Yolk Lab: prompt kios membuka modal; memilih mutasi masuk MODE APPLY (banner, highlight telur placed
-- milik sendiri, label harga saat hover). Klik/tap telur mengirim ApplyMutation; Esc atau Cancel
-- mengirim BuyMutation("cancel"). Pemilihan telur memakai proyeksi layar (tidak bergantung CanQuery).

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)
local Mutations = require(Shared.Config.Mutations)
local Net = require(Shared.Net.Net)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Types = require(Shared.Types)

local UI = script.Parent.Parent.UI
local MutationPanel = require(UI.Screens.MutationPanel)
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local ModalController = require(script.Parent.ModalController)

local MutationController = {}

local MODAL = "YolkLab"
local PICK_MIN_RADIUS = 36 -- piksel
local Attr, Tags = Types.Attr, Types.Tags

local mode = nil -- { mut, session, gui, banner, tag, highlights = {[Model]=Highlight}, conns }

local function isOwnEgg(model: Instance): boolean
	local node = model.Parent
	while node do
		local owner = node:GetAttribute(Attr.OwnerUserId)
		if owner ~= nil then
			return owner == Players.LocalPlayer.UserId
		end
		node = node.Parent
	end
	return false
end

local function addHighlight(m, model: Instance)
	if not (model:IsA("Model") and isOwnEgg(model)) or m.highlights[model] then
		return
	end
	local h = Instance.new("Highlight")
	h.Adornee = model
	h.FillColor = MutationPanel.colors[m.mut] or Theme.Colors.Yolk
	h.FillTransparency = 0.55
	h.OutlineColor = Theme.Colors.White
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = model
	m.highlights[model] = h
end

local function exitMode()
	local m = mode
	if not m then
		return
	end
	mode = nil
	for _, conn in m.conns do
		conn:Disconnect()
	end
	for _, h in m.highlights do
		h:Destroy()
	end
	m.gui:Destroy()
end

local function cancel()
	if mode then
		exitMode()
		Net.send("BuyMutation", CollectionConfig.mutation.cancelToken)
	end
end

-- Telur milik sendiri terdekat dengan titik layar (viewport), dalam radius proyeksi.
local function pickEgg(m, screenPos: Vector2)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local best, bestDist
	for model in m.highlights do
		if model.Parent then
			local pivot = model:GetPivot().Position
			local v, onScreen = camera:WorldToViewportPoint(pivot)
			if onScreen then
				local size = model:GetExtentsSize()
				local top = camera:WorldToViewportPoint(pivot + Vector3.new(0, size.Y * 0.5, 0))
				local radius = math.max(PICK_MIN_RADIUS, math.abs(top.Y - v.Y) * 1.3)
				local d = (Vector2.new(v.X, v.Y) - screenPos).Magnitude
				if d <= radius and (not bestDist or d < bestDist) then
					best, bestDist = model, d
				end
			end
		end
	end
	return best
end

local function enterMode(mutName: string)
	exitMode()
	local def = Mutations.list[mutName]
	if not def then
		return
	end

	local gui = UIBuilder.create("ScreenGui", {
		Name = "MutationApply",
		ResetOnSpawn = false,
		DisplayOrder = 40,
		IgnoreGuiInset = true,
	})
	local m = { mut = mutName, gui = gui, highlights = {}, conns = {} }
	mode = m

	local banner = UIBuilder.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(560, 50),
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 12) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
			UIBuilder.create("UISizeConstraint", { MaxSize = Vector2.new(560, 50) }),
		},
	})
	UIBuilder.create("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -120, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Theme.Colors.Brown,
		Text = `Click on an egg to apply the {mutName} mutation (Esc to cancel)`,
		Parent = banner,
	})
	Button.new({
		name = "Cancel",
		text = "Cancel",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		size = UDim2.fromOffset(96, 36),
		textSize = 16,
		onClick = cancel,
		parent = banner,
	})

	m.tag = UIBuilder.create("TextLabel", {
		Name = "PriceTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(180, 30),
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = "",
		Visible = false,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
		},
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	for _, model in CollectionService:GetTagged(Tags.PlacedEgg) do
		addHighlight(m, model)
	end
	table.insert(
		m.conns,
		CollectionService:GetInstanceAddedSignal(Tags.PlacedEgg):Connect(function(model)
			task.defer(addHighlight, m, model) -- Parent bisa belum terpasang saat tag ditambah
		end)
	)
	table.insert(
		m.conns,
		CollectionService:GetInstanceRemovedSignal(Tags.PlacedEgg):Connect(function(model)
			local h = m.highlights[model]
			if h then
				h:Destroy()
				m.highlights[model] = nil
			end
		end)
	)

	-- Label harga mengikuti telur di bawah kursor.
	table.insert(
		m.conns,
		RunService.RenderStepped:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			local model = pickEgg(m, pos)
			if model then
				local income = model:GetAttribute(Attr.Income) or 0
				m.tag.Text = "Price: " .. NumberFormat.fmtMoney(def.npcPriceMult * income)
				-- Posisi ScreenGui IgnoreGuiInset = koordinat viewport.
				m.tag.Position = UDim2.fromOffset(pos.X, pos.Y - 16)
				m.tag.Visible = true
			else
				m.tag.Visible = false
			end
		end)
	)

	table.insert(
		m.conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Escape then
				cancel()
				return
			end
			if processed then
				return
			end
			local pos
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				pos = UserInputService:GetMouseLocation()
			elseif input.UserInputType == Enum.UserInputType.Touch then
				pos = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
			end
			if not pos then
				return
			end
			local model = pickEgg(m, pos)
			local uid = model and model:GetAttribute(Attr.EggUid)
			if uid then
				Net.send("ApplyMutation", uid)
			end
		end)
	)

	-- Pilihan di server kedaluwarsa sendiri; klien ikut keluar dari mode.
	task.delay(CollectionConfig.mutation.pendingSeconds, function()
		if mode == m then
			exitMode()
		end
	end)
end

function MutationController.Start()
	ModalController.register(MODAL, function(container)
		return MutationPanel.build(container, function(mutName)
			Net.send("BuyMutation", mutName)
			ModalController.close()
			enterMode(mutName)
		end)
	end, "Yolk Lab")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if
			player == Players.LocalPlayer
			and prompt.Name == CollectionConfig.mutation.promptName
		then
			ModalController.open(MODAL)
		end
	end)

	Net.connect("MutationResult", function()
		exitMode()
	end)
end

return MutationController
