--!nonstrict
-- Tombol HUD kanan "Pets" yang membuka modal daftar pet (UI/Screens/PetsPanel).

local UI = script.Parent.Parent.UI
local PetsPanel = require(UI.Screens.PetsPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local PetsPanelController = {}

local MODAL = "Pets"

function PetsPanelController.Start()
	ModalController.register(MODAL, function(container)
		return PetsPanel.build(container, StateController)
	end, "Pets")
	HUDController.registerButton("right", {
		id = "Pets",
		text = "Pets",
		order = 20,
		onClick = function()
			if ModalController.getCurrentName() == MODAL then
				ModalController.close()
			else
				ModalController.open(MODAL)
			end
		end,
	})
end

return PetsPanelController
