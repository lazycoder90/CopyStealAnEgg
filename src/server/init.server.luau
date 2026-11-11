--!nonstrict
-- Bootstrap server: Init() semua service (tanpa yield), lalu Start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Net.Net) -- membuat folder Remotes lebih dulu

local Clock = require(script.Systems.Clock)
local DataService = require(script.Services.DataService)
local StateReplicator = require(script.Services.StateReplicator)
local AdminService = require(script.Services.AdminService)

-- Urutan penting: Data dulu, lalu replikasi, lalu service yang bergantung pada keduanya.
local services = { DataService, StateReplicator, AdminService }

for _, service in services do
	if service.Init then
		service.Init()
	end
end

-- Kirim snapshot ke klien begitu profil termuat.
DataService.onLoaded:Connect(function(player, data)
	StateReplicator.init(player, data)
end)

Clock.Start()
for _, service in services do
	if service.Start then
		service.Start()
	end
end

print("[NestBandits] Server siap. Penyimpanan persisten:", DataService.isPersistent())
