--!nonstrict
-- Tombol HUD kanan "Bag" yang membuka modal Inventaris (UI/Screens/InventoryPanel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SellConfig = require(Shared.Config.SellConfig)

local UI = script.Parent.Parent.UI
local InventoryPanel = require(UI.Screens.InventoryPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local InventoryController = {}

function InventoryController.Start()
	ModalController.register(SellConfig.modalInventory, function(container)
		return InventoryPanel.build(container, StateController, ModalController.close)
	end, "Inventory")
	HUDController.registerButton("right", {
		id = "Bag",
		text = SellConfig.bagButton,
		order = 30,
		onClick = function()
			if ModalController.getCurrentName() == SellConfig.modalInventory then
				ModalController.close()
			else
				ModalController.open(SellConfig.modalInventory)
			end
		end,
	})
end

return InventoryController
