--!nonstrict
-- Tombol HUD "Shop" (kiri, urutan 5, hijau) yang membuka modal Shop.

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local ShopPanel = require(UI.Screens.ShopPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local ShopController = {}

local MODAL = "Shop"
local TRAILS_MODAL = "TrailsShop" -- didaftarkan TrailsShopController

function ShopController.Start()
	ModalController.register(MODAL, function(container)
		return ShopPanel.build(container, StateController, {
			openTrails = function()
				ModalController.open(TRAILS_MODAL)
			end,
		})
	end, "Shop")

	HUDController.registerButton("left", {
		id = "Shop",
		text = "Shop",
		order = 5,
		color = Theme.Colors.Mint,
		onClick = function()
			ModalController.open(MODAL)
		end,
	})
end

return ShopController
