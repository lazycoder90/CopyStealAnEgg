--!nonstrict
-- HUD: Speed, Cash, $/s di kiri bawah + tumpukan tombol kiri/kanan (registerButton).
-- Notifikasi toast ada di NotificationController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Logic.NumberFormat)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local StateController = require(script.Parent.StateController)

local HUDController = {}

local stacks = {} -- slot -> Frame
local entries = {} -- id -> { slot, def, button, badge }
local started = false

local function stat(name: string, order: number, color: Color3, size: number)
	return UIBuilder.create("TextLabel", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 8),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Title,
		TextSize = size,
		TextColor3 = color,
		Text = "",
		[UIBuilder.Children] = {
			UIBuilder.create("UIStroke", {
				Thickness = Theme.StrokeThickness,
				Color = Theme.Colors.Brown,
			}),
		},
	})
end

local function updateBadge(entry)
	local fn = entry.def.badge
	local value
	if fn then
		local ok, result = pcall(fn)
		if ok then
			value = result
		end
	end
	local show = value ~= nil and value ~= 0 and value ~= ""
	entry.badge.Visible = show
	if show then
		entry.badgeLabel.Text = tostring(value)
	end
end

local function removeEntry(id: string)
	local entry = entries[id]
	if entry then
		entries[id] = nil
		entry.button:Destroy()
	end
end

local function build(id: string, slot: string, def)
	removeEntry(id)
	local stack = stacks[slot]
	if not stack then
		return
	end
	local button = Button.new({
		name = "Btn_" .. id,
		text = def.text or id,
		color = def.color or Theme.Colors.Yolk,
		size = UDim2.new(1, 0, 0, Theme.MinButtonHeight + 4),
		layoutOrder = def.order or 0,
		textSize = 20,
		onClick = def.onClick,
		parent = stack,
	})
	local badge = UIBuilder.create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Colors.Brick,
		Visible = false,
		ZIndex = 5,
		Parent = button,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.White }),
		},
	})
	local label = UIBuilder.create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = Theme.Colors.White,
		Text = "",
		ZIndex = 6,
		Parent = badge,
	})
	local entry = { slot = slot, def = def, button = button, badge = badge, badgeLabel = label }
	entries[id] = entry
	updateBadge(entry)
end

-- slot: "left" | "right"; def = { id, text, order, color?, onClick, badge? }.
function HUDController.registerButton(slot: string, def)
	if type(def) ~= "table" or type(def.id) ~= "string" then
		warn("[HUDController] def tombol tidak valid")
		return
	end
	removeEntry(def.id)
	if not started then
		-- Belum ada gui; daftar ditunda sampai Start.
		HUDController._queued = HUDController._queued or {}
		table.insert(HUDController._queued, { slot, def })
		return
	end
	build(def.id, slot, def)
end

function HUDController.refreshBadges()
	for _, entry in entries do
		updateBadge(entry)
	end
end

function HUDController.Start()
	local gui = UIBuilder.create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
	})

	local function makeStack(name: string, anchorX: number)
		return UIBuilder.create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(anchorX, 0.5),
			Position = UDim2.new(anchorX, anchorX == 0 and 12 or -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 300),
			BackgroundTransparency = 1,
			Parent = gui,
			[UIBuilder.Children] = {
				UIBuilder.create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			},
		})
	end
	stacks.left = makeStack("LeftStack", 0)
	stacks.right = makeStack("RightStack", 1)

	local bottom = UIBuilder.create("Frame", {
		Name = "BottomLeft",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(260, 110),
		BackgroundTransparency = 1,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
		},
	})
	local speed = stat("Speed", 1, Theme.Colors.White, 28)
	local cash = stat("Cash", 2, Theme.Colors.Mint, 28)
	local income = stat("Income", 3, Theme.Colors.Yolk, 22)
	speed.Parent = bottom
	cash.Parent = bottom
	income.Parent = bottom

	local function refresh()
		speed.Text = "Speed " .. NumberFormat.fmt(StateController.get("speedBase") or 0)
		cash.Text = NumberFormat.fmtMoney(StateController.get("cash") or 0)
		income.Text = NumberFormat.fmtRate(StateController.get("lastIncomePerSec") or 0)
	end

	StateController.changed:Connect(function(path)
		if path == "*" or path == "cash" or path == "speedBase" or path == "lastIncomePerSec" then
			refresh()
		end
		HUDController.refreshBadges()
	end)
	refresh()

	started = true
	for _, q in HUDController._queued or {} do
		build(q[2].id, q[1], q[2])
	end
	HUDController._queued = nil

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		while gui.Parent do
			HUDController.refreshBadges()
			task.wait(1)
		end
	end)
end

return HUDController
