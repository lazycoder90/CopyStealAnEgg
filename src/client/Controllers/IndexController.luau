--!nonstrict
-- Tombol HUD kiri "Index" (badge = jumlah reward belum diklaim) yang membuka modal "Pet Index".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IndexMath = require(Shared.Logic.IndexMath)

local UI = script.Parent.Parent.UI
local IndexPanel = require(UI.Screens.IndexPanel)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local IndexController = {}

local MODAL = "Index"

function IndexController.Start()
	ModalController.register(MODAL, function(container)
		return IndexPanel.build(container, StateController)
	end, "Pet Index")
	HUDController.registerButton("left", {
		id = "Index",
		text = "Index",
		order = 20,
		badge = function()
			local found = StateController.get("index.found") or {}
			local claimed = StateController.get("index.claimed") or {}
			return IndexMath.unclaimedCount(found, claimed)
		end,
		onClick = function()
			if ModalController.getCurrentName() == MODAL then
				ModalController.close()
			else
				ModalController.open(MODAL)
			end
		end,
	})
end

return IndexController
