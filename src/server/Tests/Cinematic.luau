--!nonstrict
-- Skenario uji bendera cinematicSeen. Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Cinematic")

local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent.Parent
local DataService = require(Server.Services.DataService)

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local bridge = ServerStorage.TestBridge
	local function call(name, ...)
		local r = bridge:Invoke(name, ...)
		if not r.ok then
			T.check("hook " .. name, false, r.error)
		end
		return r.result
	end

	-- Profil baru: belum ditonton, tutorial belum selesai.
	DataService.wipe(userId)
	T.wait(1.2)
	local data = DataService.getByUserId(userId)
	T.check("profil baru: cinematicSeen false", data.cinematicSeen == false, data.cinematicSeen)
	T.check("profil baru: tutorial belum selesai", data.tutorial.done == false)

	-- fastForward = fungsi yang sama dengan jadwal 40 detik.
	T.check("fastForward berhasil", call("cinematic.fastForward", userId) == true)
	data = DataService.getByUserId(userId)
	T.check(
		"cinematicSeen true setelah fastForward",
		data.cinematicSeen == true,
		data.cinematicSeen
	)

	-- Bertahan setelah rejoin (profil disimpan).
	call("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	T.check("cinematicSeen bertahan setelah rejoin", data.cinematicSeen == true, data.cinematicSeen)

	-- Profil lama (tutorial selesai) langsung true saat join.
	data.cinematicSeen = false
	data.tutorial.done = true
	call("lifecycle.simulateRejoin", userId)
	T.wait(1.2)
	data = DataService.getByUserId(userId)
	T.check("profil lama: langsung true", data.cinematicSeen == true, data.cinematicSeen)

	-- Rapikan: profil bersih tanpa jadwal tertunda.
	DataService.wipe(userId)
	T.wait(1.2)
	call("cinematic.fastForward", userId)
end
