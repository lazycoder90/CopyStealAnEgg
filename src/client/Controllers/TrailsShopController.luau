--!nonstrict
-- Membuka modal "Trail Shop" saat pemain menekan prompt kios TRAILS SHOP di hub.
-- Tidak ada remote: klien mendengar ProximityPromptService.PromptTriggered berdasarkan nama prompt.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)

local UI = script.Parent.Parent.UI
local TrailsShop = require(UI.Screens.TrailsShop)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local TrailsShopController = {}

local MODAL = "TrailsShop"

function TrailsShopController.Start()
	ModalController.register(MODAL, function(container)
		return TrailsShop.build(container, StateController)
	end, "Trail Shop")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player == Players.LocalPlayer and prompt.Name == Progression.trailShop.promptName then
			ModalController.open(MODAL)
		end
	end)
end

return TrailsShopController
