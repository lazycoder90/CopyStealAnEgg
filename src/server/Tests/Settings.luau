--!nonstrict
-- Skenario uji Settings. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Settings")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net.Net)

local DataService = require(Server.Services.DataService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local player = T.player
	local bridge = ServerStorage.TestBridge
	local function settings()
		return bridge:Invoke("settings.get", userId).result
	end
	local function inject(...)
		return Net.inject("SetSetting", player, ...)
	end

	DataService.wipe(userId)
	T.wait(1.2)

	local s = settings()
	T.check(
		"default: music/sfx hidup, lowGfx mati",
		s.music == true and s.sfx == true and s.lowGfx == false
	)

	T.check("music=false diterima", inject("music", false)[1] == "ok")
	T.check("music tersimpan", settings().music == false)
	T.check("lowGfx=true diterima", inject("lowGfx", true)[1] == "ok")
	T.check("sfx=false diterima", inject("sfx", false)[1] == "ok")
	T.check("lowGfx tersimpan", settings().lowGfx == true and settings().sfx == false)

	T.check("kunci tak dikenal ditolak", inject("hacked", true)[1] == "invalid")
	T.check("slowMode tidak lewat SetSetting", inject("slowMode", true)[1] == "invalid")
	T.check("nilai bukan boolean ditolak", inject("music", 1)[1] == "invalid")
	T.check("nilai teks ditolak", inject("music", "true")[1] == "invalid")
	T.check("tanpa nilai ditolak", inject("music")[1] == "invalid")
	T.check("argumen berlebih ditolak", inject("music", true, 5)[1] == "invalid")
	T.check("kunci bukan string ditolak", inject(5, true)[1] == "invalid")
	T.check("tidak ada kunci liar", settings().hacked == nil and settings().slowMode == false)

	bridge:Invoke("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	local after = settings()
	T.check(
		"rejoin menjaga pengaturan",
		after.music == false and after.lowGfx == true and after.sfx == false
	)

	-- pulihkan
	inject("music", true)
	inject("sfx", true)
	inject("lowGfx", false)
	DataService.wipe(userId)
	T.wait(1.2)
	local final = settings()
	T.check(
		"dipulihkan ke default",
		final.music == true and final.sfx == true and final.lowGfx == false
	)
end
