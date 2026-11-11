--!nonstrict
-- Uji kebocoran: simulateRejoin berulang tidak boleh menambah instance/model atau menumpuk objek.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Leak")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(Server.Services.DataService)
local InvariantChecker = require(Server.Systems.InvariantChecker)
local PetService = require(Server.Services.PetService)
local PlacementService = require(Server.Services.PlacementService)
local PlotService = require(Server.Services.PlotService)

local REJOINS = 20

local function countDescendants(inst: Instance?): number
	return inst and #inst:GetDescendants() or 0
end

local function snapshot(userId: number)
	local plot = PlotService.getPlot(userId)
	return {
		workspace = #workspace:GetDescendants(),
		worldEggs = countDescendants(workspace:FindFirstChild(Types.Names.WorldEggs)),
		guardians = countDescendants(workspace:FindFirstChild(Types.Names.Guardians)),
		effects = countDescendants(workspace:FindFirstChild(Types.Names.Effects)),
		plotEggs = plot and countDescendants(plot:FindFirstChild(Types.Names.PlotEggs)) or -1,
		plotPets = plot and countDescendants(plot:FindFirstChild(Types.Names.PlotPets)) or -1,
		memoryMb = gcinfo() / 1024,
	}
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage:FindFirstChild(Types.Names.TestBridge)

	DataService.wipe(userId)
	T.wait(1.5)
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true
	data.penLevel = 11 -- 14 slot Coop
	data.equipSlots = 5 -- cukup untuk 4 pet aktif

	-- Siapkan keadaan "ramai": 3 telur di Coop, 4 pet dipasang.
	local placed = 0
	for i = 1, 3 do
		local uid = string.format("leak%02d", i)
		PlacementService.insert(userId, {
			uid = uid,
			id = "moss_pup",
			kg = 2,
			muts = {},
			growTotal = 100000,
			progress = 10 * i,
		}, -25 + i * 14, -10)
		placed += 1
	end
	for _ = 1, 4 do
		local uid = bridge:Invoke("pets.give", userId, "moss_pup", 2).result
		PetService.equip(userId, uid)
	end
	T.wait(0.5)

	-- Pemanasan satu putaran agar objek yang dibuat sekali (cache, folder) tidak dihitung sebagai bocor.
	bridge:Invoke("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	local base = snapshot(userId)
	T.check(
		"keadaan awal: 3 model telur di Coop",
		bridge:Invoke("growth.models", userId).result == 3
	)

	for _ = 1, REJOINS do
		bridge:Invoke("lifecycle.simulateRejoin", userId)
		T.wait(0.25)
	end
	T.wait(1.5)
	local after = snapshot(userId)

	T.check(
		"model telur tetap 3 setelah 20x rejoin",
		bridge:Invoke("growth.models", userId).result == 3,
		bridge:Invoke("growth.models", userId).result
	)
	T.check(
		"folder Eggs plot stabil",
		after.plotEggs == base.plotEggs,
		`{base.plotEggs} -> {after.plotEggs}`
	)
	T.check(
		"folder ActivePets stabil",
		after.plotPets == base.plotPets,
		`{base.plotPets} -> {after.plotPets}`
	)
	T.check(
		"WorldEggs stabil (+-30)",
		math.abs(after.worldEggs - base.worldEggs) <= 30,
		`{base.worldEggs} -> {after.worldEggs}`
	)
	T.check(
		"Guardians stabil",
		after.guardians == base.guardians,
		`{base.guardians} -> {after.guardians}`
	)
	T.check(
		"Effects tidak menumpuk (+-20)",
		math.abs(after.effects - base.effects) <= 20,
		`{base.effects} -> {after.effects}`
	)
	T.check(
		"total instance Workspace tidak membengkak (+-60)",
		math.abs(after.workspace - base.workspace) <= 60,
		`{base.workspace} -> {after.workspace}`
	)
	T.check(
		"memori tidak melonjak (< +40 MB)",
		after.memoryMb - base.memoryMb < 40,
		`{base.memoryMb} -> {after.memoryMb}`
	)
	T.check("pet aktif tetap 4", PetService.equippedCount(DataService.getByUserId(userId)) == 4)
	T.check(
		"telur di profil tetap 3",
		(function()
			local n = 0
			for _, egg in DataService.getByUserId(userId).eggs do
				if egg.loc == "placed" then
					n += 1
				end
			end
			return n == placed
		end)()
	)
	T.check("Coop masih milik pemain", PlotService.getPlot(userId) ~= nil)
	T.check(
		"tidak ada model telur yatim",
		(function()
			local plot = PlotService.getPlot(userId)
			local folder = plot and plot:FindFirstChild(Types.Names.PlotEggs)
			return folder ~= nil and #folder:GetChildren() == 3
		end)()
	)

	DataService.wipe(userId)
	T.wait(1.5)
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
