--!nonstrict
-- Penempatan telur: tombol Place (key E) dan ghost egg yang berubah hijau/merah.
-- Server yang menentukan; klien hanya preview.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Types = require(Shared.Types)
local ModelFactory = require(Shared.ModelFactory)
local Eggs = require(Shared.Config.Eggs)
local Layout = require(Shared.Config.Layout)
local Creatures = require(Shared.Config.Creatures)
local Progression = require(Shared.Config.Progression)

local UI = script.Parent.Parent.UI
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)
local StateController = require(script.Parent.StateController)
local CarryController = require(script.Parent.CarryController)

local PlacementController = {}

local Attr = Types.Attr
local Tags = Types.Tags
local Names = Types.Names

local VALID_COLOR = Color3.fromRGB(90, 220, 110)
local INVALID_COLOR = Color3.fromRGB(230, 70, 60)
local LOOK_DISTANCE = 7

local player = Players.LocalPlayer
local gui, placeButton
local ghost, ghostKey, ghostHalfHeight, ghostValid
local plot, floor
local lastTarget
local lastSend = 0

local function findOwnPlot()
	if plot and plot.Parent and plot:GetAttribute(Attr.OwnerUserId) == player.UserId then
		return plot
	end
	plot, floor = nil, nil
	for _, candidate in CollectionService:GetTagged(Tags.Coop) do
		if candidate:GetAttribute(Attr.OwnerUserId) == player.UserId then
			local f = candidate:FindFirstChild(Names.PlotFloor)
			if f and f:IsA("BasePart") then
				plot, floor = candidate, f
				return plot
			end
		end
	end
	return nil
end

local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost, ghostKey, ghostValid = nil, nil, nil
	end
end

local function tintGhost(color: Color3)
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
		end
	end
end

local function ensureGhost(payload)
	local key = tostring(payload.speciesId) .. ":" .. tostring(payload.kg)
	if ghost and ghostKey == key then
		return true
	end
	destroyGhost()
	local ok, creature = pcall(Creatures.get, payload.speciesId)
	if not ok then
		return false
	end
	ghost = ModelFactory.makeEgg(creature, payload.kg or 1)
	ghost.Name = "PlacementGhost"
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0.5
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	ghostKey = key
	ghostHalfHeight = ghost:GetExtentsSize().Y / 2
	ghostValid = nil
	ghost.Parent = workspace
	return true
end

local function slotsLeft(): boolean
	local penLevel = StateController.get("penLevel") or 1
	local expansion = StateController.get("plotExpansion") or 0
	local ok, slots = pcall(Progression.eggSlotsFor, penLevel, expansion)
	if not ok then
		return true
	end
	local used = 0
	local eggs = StateController.get("eggs")
	if type(eggs) == "table" then
		for _, egg in eggs do
			if egg.loc == "placed" then
				used += 1
			end
		end
	end
	return used < slots
end

local function isValidSpot(lx: number, lz: number): boolean
	for _, r in Layout.plotReserved do
		local dx, dz = lx - r.x, lz - r.z
		if dx * dx + dz * dz < r.r * r.r then
			return false
		end
	end
	local eggs = StateController.get("eggs")
	if type(eggs) == "table" then
		local spacing = Eggs.placeMinSpacing
		for _, egg in eggs do
			local p = egg.pos
			if egg.loc == "placed" and p then
				local dx, dz = lx - p.x, lz - p.z
				if dx * dx + dz * dz < spacing * spacing then
					return false
				end
			end
		end
	end
	return slotsLeft()
end

local function place()
	if not (CarryController.isCarrying() and lastTarget) then
		return
	end
	local now = os.clock()
	if now - lastSend < 0.3 then
		return
	end
	lastSend = now
	Net.send("PlaceEgg", lastTarget)
end

local function hide()
	if placeButton.Visible then
		placeButton.Visible = false
	end
	lastTarget = nil
	destroyGhost()
end

local function step()
	local payload = CarryController.getPayload()
	if not payload then
		if ghost or placeButton.Visible then
			hide()
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and findOwnPlot() and floor) then
		hide()
		return
	end

	local cf = floor.CFrame
	local half = floor.Size * 0.5
	local lp = cf:PointToObjectSpace(root.Position)
	local ox = math.max(math.abs(lp.X) - half.X, 0)
	local oz = math.max(math.abs(lp.Z) - half.Z, 0)
	if math.sqrt(ox * ox + oz * oz) > Eggs.placeMaxDistanceFromCoop then
		hide()
		return
	end

	local ahead = root.Position + root.CFrame.LookVector * LOOK_DISTANCE
	local tl = cf:PointToObjectSpace(ahead)
	local limitX = half.X - Eggs.placeInset
	local limitZ = half.Z - Eggs.placeInset
	local lx = math.clamp(tl.X, -limitX, limitX)
	local lz = math.clamp(tl.Z, -limitZ, limitZ)
	local target = cf:PointToWorldSpace(Vector3.new(lx, half.Y, lz))
	lastTarget = target

	if not placeButton.Visible then
		placeButton.Visible = true
	end
	if not ensureGhost(payload) then
		return
	end
	ghost:PivotTo(CFrame.new(target + Vector3.new(0, ghostHalfHeight, 0)))
	local valid = isValidSpot(lx, lz)
	if valid ~= ghostValid then
		ghostValid = valid
		tintGhost(valid and VALID_COLOR or INVALID_COLOR)
	end
end

function PlacementController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Placement",
		ResetOnSpawn = false,
		DisplayOrder = 21,
	})
	placeButton = Button.new({
		name = "Place",
		text = "Place (E)",
		color = Color3.fromRGB(80, 190, 100),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -84),
		size = UDim2.fromOffset(150, 48),
		onClick = place,
		parent = gui,
	})
	placeButton.Visible = false

	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.E and placeButton.Visible then
			place()
		end
	end)
	task.spawn(function()
		gui.Parent = player:WaitForChild("PlayerGui")
	end)
end

return PlacementController
