--!nonstrict
-- PlotService: menetapkan satu Coop per pemain (kunci userId, termasuk bot), memindahkan karakter ke Coop
-- sendiri saat spawn, dan konversi koordinat dunia <-> lokal plot.
-- Koordinat lokal = relatif pusat lantai plot (sumbu X/Z), supaya data telur stabil antar sesi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Types = require(Shared.Types)
local Maid = require(Shared.Util.Maid)

local Systems = script.Parent.Parent.Systems
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local Actors = require(Systems.Actors)
local TestBridge = require(Systems.TestBridge)

local Names, Attr = Types.Names, Types.Attr

local PlotService = {}

local plotByUser = {} -- [userId] = Model
local maids = {} -- [userId] = Maid

local function plotsFolder(): Folder
	return workspace:WaitForChild(Names.Plots)
end

function PlotService.getPlot(userId: number): Model?
	return plotByUser[userId]
end

function PlotService.getPlotByIndex(index: number): Model?
	return plotsFolder():FindFirstChild(`Plot_{index}`)
end

function PlotService.getOwnerUserId(plot: Model): number
	return plot:GetAttribute(Attr.OwnerUserId) or 0
end

function PlotService.getFloor(plot: Model): BasePart
	return plot:FindFirstChild(Names.PlotFloor)
end

-- Titik permukaan lantai (y = 0) dari koordinat lokal.
function PlotService.localToWorld(plot: Model, x: number, z: number): Vector3
	local floor = PlotService.getFloor(plot)
	local p = floor.CFrame:PointToWorldSpace(Vector3.new(x, floor.Size.Y / 2, z))
	return p
end

-- Koordinat lokal (x, z) dari posisi dunia.
function PlotService.worldToLocal(plot: Model, worldPos: Vector3): (number, number)
	local floor = PlotService.getFloor(plot)
	local p = floor.CFrame:PointToObjectSpace(worldPos)
	return p.X, p.Z
end

-- Apakah titik lokal berada di dalam lantai plot dengan jarak aman dari tepi.
function PlotService.isInsideLocal(x: number, z: number, inset: number): boolean
	local limit = Layout.plotSize / 2 - inset
	return math.abs(x) <= limit and math.abs(z) <= limit
end

-- Jarak (stud) dari posisi dunia ke persegi lantai plot (0 jika di dalam).
function PlotService.distanceToPlot(plot: Model, worldPos: Vector3): number
	local x, z = PlotService.worldToLocal(plot, worldPos)
	local half = Layout.plotSize / 2
	local dx = math.max(math.abs(x) - half, 0)
	local dz = math.max(math.abs(z) - half, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Apakah titik lokal bersinggungan dengan area terlarang (spawn, Sprint Wheel).
function PlotService.isReservedLocal(x: number, z: number): boolean
	for _, area in Layout.plotReserved do
		local dx, dz = x - area.x, z - area.z
		if dx * dx + dz * dz <= area.r * area.r then
			return true
		end
	end
	return false
end

local function setSignOwner(plot: Model, text: string, sub: string)
	local anchor = plot:FindFirstChild("SignAnchor")
	local gui = anchor and anchor:FindFirstChild("Sign")
	if not gui then
		return
	end
	local labels = gui:GetChildren()
	for _, label in labels do
		if label:IsA("TextLabel") then
			if label.Position.Y.Scale == 0 then
				label.Text = text
			else
				label.Text = sub
			end
		end
	end
end

-- Pindahkan karakter ke titik spawn Coop. onlyIfFar: hanya jika pemain masih > 30 stud dari titik itu.
function PlotService.teleportToPlot(userId: number, onlyIfFar: boolean?)
	local plot = plotByUser[userId]
	local root = Actors.getRoot(userId)
	local character = Actors.getCharacter(userId)
	if not (plot and root and character) then
		return
	end
	local spawn = plot:FindFirstChild(Names.PlotSpawn)
	if not spawn then
		return
	end
	if onlyIfFar and (root.Position - spawn.Position).Magnitude <= 30 then
		return
	end
	character:PivotTo(spawn.CFrame * CFrame.new(0, 3, 0))
end

-- Mesin Roblox dapat menempatkan karakter di SpawnLocation sesaat SETELAH CharacterAdded,
-- jadi pemindahan diulang beberapa kali dalam 0.7 detik (hanya jika masih jauh dari Coop).
local function placeCharacterAtPlot(userId: number, character: Model)
	character:WaitForChild("HumanoidRootPart", 5)
	local plot = plotByUser[userId]
	for _, delay in { 0, 0.1, 0.25, 0.5 } do
		if delay > 0 then
			task.wait(delay)
		end
		if plotByUser[userId] ~= plot or Actors.getCharacter(userId) ~= character then
			return
		end
		PlotService.teleportToPlot(userId, delay > 0)
	end
end

local function claim(ctx)
	local userId = ctx.userId
	if plotByUser[userId] then
		return
	end
	for i = 1, Layout.plotCount do
		local plot = PlotService.getPlotByIndex(i)
		if plot and PlotService.getOwnerUserId(plot) == 0 then
			plot:SetAttribute(Attr.OwnerUserId, userId)
			plotByUser[userId] = plot
			setSignOwner(plot, `{ctx.name}'s Coop`, `Coop {i}`)

			local maid = Maid.new()
			maids[userId] = maid
			if ctx.player then
				maid:Give(ctx.player.CharacterAdded:Connect(function(character)
					placeCharacterAtPlot(userId, character)
				end))
				if ctx.player.Character then
					task.spawn(placeCharacterAtPlot, userId, ctx.player.Character)
				end
			end
			return
		end
	end
	warn("[PlotService] tidak ada Coop kosong untuk user", userId)
end

local function release(ctx)
	local userId = ctx.userId
	local plot = plotByUser[userId]
	local maid = maids[userId]
	if maid then
		maid:Clean()
		maids[userId] = nil
	end
	if plot then
		plot:SetAttribute(Attr.OwnerUserId, 0)
		setSignOwner(plot, `Coop {plot:GetAttribute(Attr.PlotIndex)}`, "Free - claim by joining")
		plotByUser[userId] = nil
	end
end

function PlotService.Init()
	-- order 5: sebelum service lain yang butuh plot saat join; 90: setelah service lain dibersihkan.
	PlayerLifecycle.onJoin("PlotService", 5, claim)
	PlayerLifecycle.onLeaving("PlotService", 90, release)

	TestBridge.register("plot.teleport", function(userId)
		PlotService.teleportToPlot(userId)
		return true
	end)
	TestBridge.register("plot.distanceToSpawn", function(userId)
		local plot = plotByUser[userId]
		local root = Actors.getRoot(userId)
		local spawn = plot and plot:FindFirstChild(Names.PlotSpawn)
		return root and spawn and (root.Position - spawn.Position).Magnitude
	end)
	TestBridge.register("plot.info", function(userId)
		local plot = plotByUser[userId]
		if not plot then
			return nil
		end
		local floor = PlotService.getFloor(plot)
		return {
			index = plot:GetAttribute(Attr.PlotIndex),
			center = { floor.Position.X, floor.Position.Y, floor.Position.Z },
			owner = PlotService.getOwnerUserId(plot),
		}
	end)
end

return PlotService
