--!nonstrict
-- Astronomer Tilly (kios Signal Tower): saat prompt ditekan, buka puzzle Star Relay bila relay belum
-- diperbaiki, selain itu panel trade Stardust. Server (StarwhaleService) mengirim puzzle sendiri.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)

local UI = script.Parent.Parent.UI
local TillyTrade = require(UI.Screens.TillyTrade)
local ModalController = require(script.Parent.ModalController)
local RelayPuzzleController = require(script.Parent.RelayPuzzleController)
local StateController = require(script.Parent.StateController)

local TillyController = {}

function TillyController.Start()
	ModalController.register(StarwhaleConfig.modalTrade, function(container)
		return TillyTrade.build(container, StateController)
	end, "Astronomer Tilly")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer or prompt.Name ~= StarwhaleConfig.promptName then
			return
		end
		if StateController.get("starwhale.relayFixed") == true then
			ModalController.open(StarwhaleConfig.modalTrade)
		else
			RelayPuzzleController.clear()
			ModalController.open(StarwhaleConfig.modalRelay)
		end
	end)
end

return TillyController
