--!nonstrict
-- Membuka modal "Sell" saat pemain menekan prompt kios SELL di hub (tanpa remote untuk membuka).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SellConfig = require(Shared.Config.SellConfig)

local UI = script.Parent.Parent.UI
local SellPanel = require(UI.Screens.SellPanel)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local SellController = {}

function SellController.Start()
	ModalController.register(SellConfig.modalSell, function(container)
		return SellPanel.build(container, StateController)
	end, "Sell")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player == Players.LocalPlayer and prompt.Name == SellConfig.promptName then
			ModalController.open(SellConfig.modalSell)
		end
	end)
end

return SellController
