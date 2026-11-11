--!nonstrict
-- Efek lokal Nestwarden: getar kamera saat GuardianAlert (skala jarak) dan Highlight merah pada
-- guardian yang sedang mengejar (atribut GuardianState == "Chase"). Tanpa audio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuardianConfig = require(Shared.Config.GuardianConfig)
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)

local ImpactController = require(script.Parent.ImpactController)

local GuardianFXController = {}

local MAX_SHAKE = 1.0
local MIN_SHAKE = 0.15
local SHAKE_SECONDS = 1.0

local tracked = {} -- [Model] = { conn, highlight }

local function setHighlight(model: Model, on: boolean)
	local entry = tracked[model]
	if not entry then
		return
	end
	if on and not entry.highlight then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.8
		highlight.FillColor = Color3.fromRGB(198, 70, 52)
		highlight.OutlineColor = Color3.fromRGB(255, 60, 40)
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = model
		entry.highlight = highlight
	elseif not on and entry.highlight then
		entry.highlight:Destroy()
		entry.highlight = nil
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local entry = { highlight = nil }
	tracked[model] = entry
	entry.conn = model:GetAttributeChangedSignal(Types.Attr.GuardianState):Connect(function()
		setHighlight(model, model:GetAttribute(Types.Attr.GuardianState) == "Chase")
	end)
	setHighlight(model, model:GetAttribute(Types.Attr.GuardianState) == "Chase")
end

local function untrack(model: Instance)
	local entry = tracked[model]
	if not entry then
		return
	end
	entry.conn:Disconnect()
	if entry.highlight then
		entry.highlight:Destroy()
	end
	tracked[model] = nil
end

local function onAlert(payload)
	if type(payload) ~= "table" then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local distance = GuardianConfig.alertShakeRadius
	for _, model in CollectionService:GetTagged(Types.Tags.Guardian) do
		if model:GetAttribute(Types.Attr.ZoneIndex) == payload.zone then
			distance = (model:GetPivot().Position - root.Position).Magnitude
			break
		end
	end
	local k = math.clamp(1 - distance / GuardianConfig.alertShakeRadius, 0, 1)
	ImpactController.shake(MIN_SHAKE + (MAX_SHAKE - MIN_SHAKE) * k, SHAKE_SECONDS)
end

function GuardianFXController.Start()
	Net.connect("GuardianAlert", onAlert)
	CollectionService:GetInstanceAddedSignal(Types.Tags.Guardian):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Types.Tags.Guardian):Connect(untrack)
	for _, model in CollectionService:GetTagged(Types.Tags.Guardian) do
		track(model)
	end
end

return GuardianFXController
