--!nonstrict
-- AnnouncementService: pengumuman berwarna ke semua pemain (feed di atas layar + chat sistem).
-- API (server): broadcast(segments), send(player, segments), text(str, color?), rarity(rarityIndex, name).
-- segments = { {text, color={r,g,b}?}, ... }. Klien (AnnouncementController) menampilkan feed 3 baris.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Rarities = require(Shared.Config.Rarities)

local AnnouncementService = {}

local WHITE = { 255, 255, 255 }

-- Satu segmen teks biasa.
function AnnouncementService.text(str: string, color: { number }?)
	return { text = str, color = color or WHITE }
end

-- Segmen berwarna sesuai rarity.
function AnnouncementService.rarity(rarityIndex: number, name: string?)
	local rarity = Rarities.get(rarityIndex)
	return { text = name or rarity.name, color = rarity.rgb }
end

local function sanitize(segments)
	local out = {}
	for _, seg in segments do
		if type(seg) == "table" and type(seg.text) == "string" then
			table.insert(out, { text = string.sub(seg.text, 1, 80), color = seg.color or WHITE })
		end
	end
	return out
end

function AnnouncementService.broadcast(segments)
	local clean = sanitize(segments)
	if #clean > 0 then
		Net.fireAll("Announce", { segments = clean })
	end
end

function AnnouncementService.send(player: Player, segments)
	local clean = sanitize(segments)
	if #clean > 0 then
		Net.fire("Announce", player, { segments = clean })
	end
end

return AnnouncementService
