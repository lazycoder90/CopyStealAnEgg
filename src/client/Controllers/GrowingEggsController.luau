--!nonstrict
-- Tombol HUD kanan "Eggs" dengan badge "<tumbuh>/<siap>" yang membuka modal "Growing Eggs".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SellConfig = require(Shared.Config.SellConfig)

local UI = script.Parent.Parent.UI
local GrowingEggsPanel = require(UI.Screens.GrowingEggsPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local GrowingEggsController = {}

-- "3/1" = 3 tumbuh, 1 siap (hanya telur yang ditaruh); nil jika keduanya 0.
local function badge()
	local growing, ready = GrowingEggsPanel.counts(StateController)
	if growing == 0 and ready == 0 then
		return nil
	end
	return `{growing}/{ready}`
end

function GrowingEggsController.Start()
	ModalController.register(SellConfig.modalGrowing, function(container)
		return GrowingEggsPanel.build(container, StateController)
	end, "Growing Eggs")
	HUDController.registerButton("right", {
		id = "Eggs",
		text = SellConfig.eggsButton,
		order = 10,
		badge = badge,
		onClick = function()
			if ModalController.getCurrentName() == SellConfig.modalGrowing then
				ModalController.close()
			else
				ModalController.open(SellConfig.modalGrowing)
			end
		end,
	})
end

return GrowingEggsController
