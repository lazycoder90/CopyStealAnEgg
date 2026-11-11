--!nonstrict
-- ZoneService: zona saat ini tiap pemain (Layout.zoneAtZ dari Z root; nil = hub), disampel 4 Hz waktu nyata.
-- Memancarkan GameEvents.ZoneChanged({ userId, zone }) saat berubah.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)

local Systems = script.Parent.Parent.Systems
local Actors = require(Systems.Actors)
local GameEvents = require(Systems.GameEvents)
local PlayerLifecycle = require(Systems.PlayerLifecycle)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local ZoneService = {}

local SAMPLE_INTERVAL = 0.25 -- 4 Hz
local HUB = "hub" -- penanda "tidak di zona manapun" (nil tidak bisa jadi nilai tabel)

local current = {} -- [userId] = zona (number) atau HUB
local accumulator = 0

function ZoneService.getZone(userId: number): number?
	local zone = current[userId]
	if zone == HUB then
		return nil
	end
	return zone
end

local function sample(userId: number)
	local root = Actors.getRoot(userId)
	if not root then
		return
	end
	local zone = Layout.zoneAtZ(root.Position.Z) or HUB
	if current[userId] ~= zone then
		current[userId] = zone
		GameEvents.ZoneChanged:Fire({ userId = userId, zone = if zone == HUB then nil else zone })
	end
end

local function teleport(userId: number, cframe: CFrame)
	local character = Actors.getCharacter(userId)
	if not character then
		return false
	end
	AntiExploit.grace(userId, 3, "admin_tp")
	character:PivotTo(cframe)
	local root = Actors.getRoot(userId)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	sample(userId)
	return true
end

function ZoneService.Init()
	PlayerLifecycle.onLeaving("ZoneService", 100, function(ctx)
		current[ctx.userId] = nil
	end)

	TestBridge.register("zone.get", function(userId)
		return ZoneService.getZone(userId)
	end)

	AdminService.register("tp", function(player, args)
		local where = string.lower(args[1] or "")
		if where == "hub" then
			AntiExploit.grace(player.UserId, 3, "admin_tp")
			PlotService.teleportToPlot(player.UserId)
			return "Teleport ke Coop"
		end
		local zone = tonumber(where)
		if not zone or zone % 1 ~= 0 or zone < 1 or zone > 12 then
			return "Pakai: tp <1..12|hub>"
		end
		if not teleport(player.UserId, CFrame.new(0, 6, Layout.zoneZStart(zone) + 10)) then
			return "Karakter belum siap"
		end
		return `Teleport ke zona {zone}`
	end)
end

function ZoneService.Start()
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		for _, entry in DataService.all() do
			sample(entry.userId)
		end
	end)
end

return ZoneService
