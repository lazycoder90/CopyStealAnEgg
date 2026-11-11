--!nonstrict
-- Bootstrap server. Semua modul di Systems/ dan Services/ dimuat otomatis oleh Boot.
-- Systems dimuat lebih dulu (MapBuilder membangun dunia di Init sebelum service apa pun).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Net.Net) -- membuat folder Remotes lebih dulu

local Boot = require(script.Boot)
local DataService = require(script.Services.DataService)

Boot.run({ script.Systems, script.Services })

print(
	"[NestBandits] Server siap. Modul dimuat:",
	#Boot.loaded,
	"gagal:",
	#Boot.failed,
	"persisten:",
	DataService.isPersistent()
)
