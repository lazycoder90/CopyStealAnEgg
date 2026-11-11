--!nonstrict
-- Skenario uji: mati saat membawa telur -> telur jatuh; respawn di Coop sendiri; telur kembali ke sarang.
-- Lambat (~25 detik). Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Death")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Types = require(ReplicatedStorage.Shared.Types)

local Actors = require(Server.Systems.Actors)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local CarryService = require(Server.Services.CarryService)
local DataService = require(Server.Services.DataService)
local EggSpawnService = require(Server.Services.EggSpawnService)
local PlotService = require(Server.Services.PlotService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId

	DataService.wipe(userId)
	T.wait(1.2) -- join ulang memindahkan pemain ke Coop sampai ~0.85 detik

	-- Ambil telur zona 1
	local root = Actors.getRoot(userId)
	local best, bestDist
	for _, model in workspace[Types.Names.WorldEggs]:GetChildren() do
		local uid = model:GetAttribute(Types.Attr.EggUid)
		local entity = uid and EggSpawnService.getEntity(uid)
		if entity and entity.state == "Occupied" and entity.zone == 1 then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = entity, d
			end
		end
	end
	root.CFrame = CFrame.new(EggSpawnService.entityPosition(best) + Vector3.new(4, 4, 0))
	T.wait(0.2)
	local ok = CarryService.tryPickupWorld(userId, best.uid)
	T.check("grab sebelum mati", ok == true)

	local oldCharacter = Actors.getCharacter(userId)
	Actors.getHumanoid(userId).Health = 0
	T.wait(0.6)
	T.check("tidak membawa lagi setelah mati", not CarryService.isCarrying(userId))
	T.check(
		"telur jatuh (Dropped) dan tidak ikut hilang",
		best.state == "Dropped" and best.model ~= nil and best.model.Parent ~= nil,
		best.state
	)
	T.check(
		"model telur tidak ikut terhapus bersama karakter",
		best.model.Parent == workspace[Types.Names.WorldEggs]
	)

	-- Respawn
	local respawned = false
	for _ = 1, 100 do
		local c = Actors.getCharacter(userId)
		if c and c ~= oldCharacter and c:FindFirstChild("HumanoidRootPart") then
			respawned = true
			break
		end
		T.wait(0.1)
	end
	T.check("karakter respawn", respawned)
	T.wait(1.2)
	local plot = PlotService.getPlot(userId)
	local spawn = plot[Types.Names.PlotSpawn]
	local dist = (Actors.getRoot(userId).Position - spawn.Position).Magnitude
	T.check("respawn di Coop sendiri", dist < 12, dist)

	-- Telur jatuh kembali ke sarang setelah jeda
	T.wait(Eggs.worldEggReturnTime + 2)
	T.check("telur kembali ke sarang (Occupied)", best.state == "Occupied", best.state)
	T.check("tidak ada telur Dropped tersisa", EggSpawnService.stats().Dropped == 0)

	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
