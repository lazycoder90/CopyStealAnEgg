--!nonstrict
-- Menyembunyikan (lokal) prompt upgrade Pen/Ekspansi/Roda pada Coop milik pemain lain.
-- Server tetap memvalidasi pemilik; ini hanya merapikan tampilan.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local UpgradeController = {}

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags
local player = Players.LocalPlayer

local function isUpgradePrompt(prompt: ProximityPrompt): boolean
	return prompt:FindFirstAncestor(Names.PlotWheel) ~= nil
		or prompt:FindFirstAncestor(Names.PlotPenSign) ~= nil
		or prompt:FindFirstAncestor(Names.PlotExpansionSign) ~= nil
end

local function apply(plot: Instance)
	local mine = plot:GetAttribute(Attr.OwnerUserId) == player.UserId
	for _, d in plot:GetDescendants() do
		if d:IsA("ProximityPrompt") and isUpgradePrompt(d) then
			d.Enabled = mine
		end
	end
end

local function watch(plot: Instance)
	apply(plot)
	plot:GetAttributeChangedSignal(Attr.OwnerUserId):Connect(function()
		apply(plot)
	end)
	plot.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			task.defer(apply, plot)
		end
	end)
end

function UpgradeController.Start()
	for _, plot in CollectionService:GetTagged(Tags.Coop) do
		watch(plot)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Coop):Connect(function(plot)
		watch(plot)
	end)
end

return UpgradeController
