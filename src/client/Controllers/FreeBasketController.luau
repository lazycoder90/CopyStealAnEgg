--!nonstrict
-- Chip Free Basket di HUD kiri bawah: "Basket ready!" (klik = klaim) atau hitung mundur m:ss.
-- Server mereplikasi `freeBasketIn` (sisa detik); klien menghitung mundur sendiri di antara update.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Button = require(UI.Components.Button)
local UIBuilder = require(UI.UIBuilder)
local StateController = require(script.Parent.StateController)

local FreeBasketController = {}

local gui, chip
local baseIn, baseAt = nil, 0 -- sisa detik dari server dan waktu lokal saat diterima

local function captureBase()
	baseIn = StateController.get("freeBasketIn")
	baseAt = os.clock()
end

-- Mengembalikan sisa detik, atau nil bila belum diketahui (menunggu update server).
local function remaining()
	if baseIn == nil then
		if (StateController.get("freeBasketAt") or 0) > 0 then
			return nil
		end
		return 0
	end
	return math.max(0, baseIn - (os.clock() - baseAt))
end

local function refresh()
	if not chip then
		return
	end
	local left = remaining()
	if left == nil then
		chip.Text = "Basket..."
		Button.setDisabled(chip, true)
	elseif left <= 0 then
		chip.Text = "Basket ready!"
		chip.BackgroundColor3 = Theme.Colors.Yolk
		Button.setDisabled(chip, false)
	else
		local seconds = math.ceil(left)
		chip.Text = string.format("Basket %d:%02d", seconds // 60, seconds % 60)
		Button.setDisabled(chip, true)
	end
end

function FreeBasketController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "FreeBasket",
		ResetOnSpawn = false,
		DisplayOrder = 5,
	})
	chip = Button.new({
		name = "BasketChip",
		text = "Basket...",
		color = Theme.Colors.Yolk,
		size = UDim2.fromOffset(170, 40),
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.new(0, 16, 1, -158),
		textSize = 20,
		parent = gui,
		onClick = function()
			local left = remaining()
			if left ~= nil and left <= 0 then
				Net.send("ClaimFreeBasket")
			end
		end,
	})
	Button.setDisabled(chip, true)

	StateController.changed:Connect(function(path)
		if path == "*" or path == "freeBasketIn" then
			captureBase()
			refresh()
		end
	end)
	captureBase()
	refresh()

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		while gui.Parent do
			refresh()
			task.wait(0.25)
		end
	end)
end

return FreeBasketController
