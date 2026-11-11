--!nonstrict
-- Bootstrap klien. Semua modul di Controllers/ dimuat otomatis; ClientReady dikirim setelah
-- semua Start selesai sehingga snapshot state dari server tidak terlewat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net.Net)
local Boot = require(script.Boot)

Boot.run({ script.Controllers })

Net.send("ClientReady")
