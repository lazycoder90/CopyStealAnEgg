--!nonstrict
-- Membuka modal "Fuse Machine" saat pemain menekan prompt kios FUSE MACHINE di hub.
-- Hasil fuse (FuseResult) ditampilkan oleh HatchRevealController.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared.Config.CollectionConfig)

local UI = script.Parent.Parent.UI
local FusePanel = require(UI.Screens.FusePanel)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local FuseController = {}

local MODAL = "Fuse"

function FuseController.Start()
	ModalController.register(MODAL, function(container)
		return FusePanel.build(container, StateController)
	end, "Fuse Machine")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player == Players.LocalPlayer and prompt.Name == CollectionConfig.fuse.promptName then
			ModalController.open(MODAL)
		end
	end)
end

return FuseController
