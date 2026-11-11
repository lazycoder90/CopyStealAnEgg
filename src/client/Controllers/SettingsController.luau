--!nonstrict
-- Tombol HUD "Settings" (kanan, order 60) + modal Settings: Music (Coming soon), Sound Effects,
-- Low Graphics, Slow Mode, Replay intro. Nilai dibaca dari state yang direplikasi.
--
-- PETA LAYOUT HUD (setelah audit Wave 5; semua dalam piksel sebelum UIScale):
--   HUD.LeftStack        anchor (0,0.5)  pos (12, 0.5H-80)   110 lebar; tombol Index/Slow/Trap/Shield
--   HUD.RightStack       anchor (1,0.5)  pos (W-12, 0.5H-56) 110 lebar; Eggs/Pets/Bag/Bud/Race/Settings (6 x 52)
--   HUD.BottomLeft       anchor (0,1)    pos (16, H-16)      260x136; Speed/Cash/Income/FriendBoost
--   FreeBasket.BasketChip anchor (0,1)   pos (16, H-150)     170x40  (tumpang 2 px dgn BottomLeft; saran -158)
--   StarwhaleHUD.StardustChip anchor (0,1) pos (16, H-190)   170x34  (bersentuhan dgn BasketChip; saran -198)
--   Race.RaceHud         pos (12, 8)  230x128 (menimpa LeftStack saat race; saran x=134)
--   WorldEventHUD.ChipStack anchor (1,1) pos (W-16, H-16)    200x100 (DayNight + EggReset chip)
--   Carry.Drop           anchor (0.5,1)  pos (W/2, H-24)     150x48
--   Placement.Place      anchor (0.5,1)  pos (W/2, H-84)     150x48
--   PanCooldown.Ring     anchor (0.5,1)  pos (W/2, H-96)     120x8   (menimpa Place; saran H-140)
--   Tutorial.Skip        anchor (0.5,1)  pos (W/2, H-6) dalam frame Objective (y 150..234, di tengah atas)
--   Top tengah (y dari atas): OfflineBanner 16..72, ZoneBanner 10..102, Carry.Banner 12..76, StarwhaleHUD.Banner 44..74,
--     Carry.Chip 90..140, AnnouncementFeed 96..198, Toasts 70..230, StealAlert 150..202, Tutorial.Objective 150..234,
--     BigCountdown 200..264. Sebagian bersifat sementara; yang sering bertumpuk: ZoneBanner/Carry.Banner
--     dan Toasts/AnnouncementFeed/Tutorial.Objective.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local SettingsPanel = require(script.Parent.Parent.UI.Screens.SettingsPanel)
local CinematicController = require(script.Parent.CinematicController)
local HUDController = require(script.Parent.HUDController)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local SettingsController = {}

local MODAL_NAME = "Settings"

local function getValue(key: string): boolean
	local value = StateController.get("settings." .. key)
	if value == nil then
		-- Default profil: suara menyala, sisanya mati.
		return key == "music" or key == "sfx"
	end
	return value == true
end

local function toggle(key: string)
	local nextValue = not getValue(key)
	if key == "slowMode" then
		Net.send("SetSlowMode", nextValue)
	elseif key == "music" or key == "sfx" or key == "lowGfx" then
		Net.send("SetSetting", key, nextValue)
	end
end

local function replay()
	ModalController.close()
	task.spawn(CinematicController.run, true)
end

function SettingsController.Start()
	ModalController.register(MODAL_NAME, function(container)
		return SettingsPanel.build(
			container,
			{ get = getValue, toggle = toggle, replay = replay },
			StateController.changed
		)
	end, "Settings")

	HUDController.registerButton("right", {
		id = "Settings",
		text = "Settings",
		order = 60,
		onClick = function()
			ModalController.open(MODAL_NAME)
		end,
	})
end

return SettingsController
