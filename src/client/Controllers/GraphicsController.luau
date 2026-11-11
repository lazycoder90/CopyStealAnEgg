--!nonstrict
-- Mode grafis rendah (settings.lowGfx): matikan partikel/trail dunia, bayangan global, dan beri sinyal
-- ke ZoneAtmosphere/Juice. Nilai awal disimpan saat pertama kali diubah lalu dipulihkan.
-- API: GraphicsController.isLow(), GraphicsController.changed (Signal: low:boolean).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local StateController = require(script.Parent.StateController)

local GraphicsController = {}
GraphicsController.changed = Signal.new()

local low = false
local savedShadows = nil
local disabled = setmetatable({}, { __mode = "k" }) -- emitter -> true (yang dimatikan modul ini)
local addedConn = nil
local scanId = 0

function GraphicsController.isLow(): boolean
	return low
end

-- Penanda gameplay (guardian, trap, shield, dst.) tidak boleh dimatikan.
local function isGameplay(inst: Instance): boolean
	local node = inst
	while node and node ~= workspace do
		for _, tag in Types.Tags do
			if CollectionService:HasTag(node, tag) then
				return true
			end
		end
		node = node.Parent
	end
	return false
end

local function inCharacter(inst: Instance): boolean
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function tryDisable(inst: Instance)
	if not (inst:IsA("ParticleEmitter") or inst:IsA("Trail")) then
		return
	end
	if not inst.Enabled or disabled[inst] or inCharacter(inst) or isGameplay(inst) then
		return
	end
	disabled[inst] = true
	inst.Enabled = false
end

local function scanWorkspace()
	scanId += 1
	local mine = scanId
	local count = 0
	for _, inst in workspace:GetDescendants() do
		if mine ~= scanId or not low then
			return
		end
		tryDisable(inst)
		count += 1
		if count % 500 == 0 then
			task.wait()
		end
	end
end

local function apply(value: boolean)
	if value == low then
		return
	end
	low = value
	if low then
		if savedShadows == nil then
			savedShadows = Lighting.GlobalShadows
		end
		Lighting.GlobalShadows = false
		task.spawn(scanWorkspace)
		addedConn = workspace.DescendantAdded:Connect(tryDisable)
	else
		scanId += 1
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		if savedShadows ~= nil then
			Lighting.GlobalShadows = savedShadows
		end
		for emitter in disabled do
			if emitter.Parent then
				emitter.Enabled = true
			end
		end
		table.clear(disabled)
	end
	GraphicsController.changed:Fire(low)
end

local function read()
	apply(StateController.get("settings.lowGfx") == true)
end

function GraphicsController.Start()
	StateController.changed:Connect(function(path)
		if path == "*" or path == "settings" or path == "settings.lowGfx" then
			read()
		end
	end)
	if StateController.isReady then
		read()
	end
end

return GraphicsController
