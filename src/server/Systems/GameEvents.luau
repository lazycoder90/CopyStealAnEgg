--!nonstrict
-- Bus event gameplay (hanya server). Service memancarkan, service lain berlangganan.
-- Semua payload berupa satu tabel. Field userId selalu number.
--
-- EggSpawned   { zone, speciesId, rarity, grand, nestId }
-- EggGrabbed   { userId, eggUid, speciesId, rarity, zone, grand }
-- EggPlaced    { userId, eggUid, speciesId, stolen }
-- EggHatched   { userId, petUid, speciesId, rarity, zone, isNew }
-- EggStolen    { thiefId, victimId, eggUid, speciesId, rarity }
-- PlayerCaught { userId, zone }
-- Bonked       { userId, byUserId }
-- ZoneChanged  { userId, zone (number?) }
-- PurchaseGranted { userId, kind, id }

local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)

local names = {
	"EggSpawned",
	"EggGrabbed",
	"EggPlaced",
	"EggHatched",
	"EggStolen",
	"PlayerCaught",
	"Bonked",
	"ZoneChanged",
	"PurchaseGranted",
}

local GameEvents = {}
for _, name in names do
	GameEvents[name] = Signal.new()
end

return GameEvents
