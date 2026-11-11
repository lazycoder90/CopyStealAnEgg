--!nonstrict
-- Efek suara: kolam 6 Sound di SoundService (round robin). Hanya aset bawaan yang aman;
-- variasi lewat PlaybackSpeed. Tidak ada musik (tidak ada aset aman).
-- API: SoundController.play(name). Tidak melakukan apa-apa saat settings.sfx == false.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local PolishConfig = require(Shared.Config.PolishConfig)

local StateController = require(script.Parent.StateController)

local SoundController = {}

local pool = {} -- daftar Sound
local nextIndex = 1
local raceOpen = false

function SoundController.play(name: string)
	local def = PolishConfig.sounds[name]
	if not def or #pool == 0 then
		return
	end
	if StateController.get("settings.sfx") == false then
		return
	end
	local sound = pool[nextIndex]
	nextIndex = nextIndex % #pool + 1
	sound.SoundId = PolishConfig.soundPath .. def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.speed
	sound.TimePosition = 0
	sound:Play()
end

local function preload()
	local items = {}
	local seen = {}
	for _, def in PolishConfig.sounds do
		if not seen[def.id] then
			seen[def.id] = true
			local sound = Instance.new("Sound")
			sound.SoundId = PolishConfig.soundPath .. def.id
			table.insert(items, sound)
		end
	end
	local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, items)
	if not ok then
		warn("[SoundController] preload gagal:", err)
	end
	for _, sound in items do
		sound:Destroy()
	end
end

function SoundController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "NBSfx"
	for i = 1, PolishConfig.poolSize do
		local sound = Instance.new("Sound")
		sound.Name = "Sfx" .. i
		sound.RollOffMaxDistance = 0
		sound.Parent = folder
		table.insert(pool, sound)
	end
	folder.Parent = SoundService

	-- Hook generik dari remote server supaya controller lain tidak perlu diubah.
	Net.connect("Bonked", function()
		SoundController.play("bonk")
	end)
	Net.connect("Trapped", function()
		SoundController.play("trap")
	end)
	Net.connect("Notify", function(_message, kind)
		if kind == "error" then
			SoundController.play("error")
		end
	end)
	Net.connect("RaceState", function(payload)
		if type(payload) ~= "table" then
			return
		end
		local open = payload.phase == "Open"
		if open and not raceOpen then
			SoundController.play("race_go")
		end
		raceOpen = open
	end)

	task.spawn(preload)
end

return SoundController
