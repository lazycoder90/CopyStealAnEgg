--!strict
-- Matematika murni event Starwhale: posisi telur aneh (deterministik), roll Stardust,
-- validasi penawaran trade, dan arah/kedip kompas. Bisa dites di Lune.

local Layout = require("../Config/Layout")
local MutationLogic = require("./MutationLogic")
local RNG = require("./RNG")
local StarwhaleConfig = require("../Config/StarwhaleConfig")

export type Vec = { number }
export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type EggInfo = { loc: string?, muts: { string }?, frozen: boolean? }

local StarwhaleMath = {}

-- Batas dalam lane (dikurangi inset) untuk zona yang memuat koordinat z.
function StarwhaleMath.laneBounds(z: number): Bounds
	local inset = StarwhaleConfig.oddEdgeInset
	local half = Layout.laneWidth / 2
	local zone = Layout.zoneAtZ(z) or 1
	return {
		minX = -half + inset,
		maxX = half - inset,
		minZ = Layout.zoneZStart(zone) + inset,
		maxZ = Layout.zoneZEnd(zone) - inset,
	}
end

-- Seed telur aneh per pemain per kunjungan.
function StarwhaleMath.oddSeed(visitId: number, userId: number): number
	return visitId * 100003 + userId
end

-- Posisi telur aneh {x,y,z}: dalam oddRadius dari paus (bidang XZ), minimal oddMinFromWhale dari paus,
-- jarak antar telur >= oddSpacing, di dalam batas lane. Deterministik terhadap seed.
function StarwhaleMath.oddPositions(seed: number, whale: Vec, bounds: Bounds?): { Vec }
	local b = bounds or StarwhaleMath.laneBounds(whale[3])
	local rng = RNG.new(seed)
	local count = StarwhaleConfig.oddCount
	local spacing = StarwhaleConfig.oddSpacing
	local out: { Vec } = {}

	local function valid(x: number, z: number): boolean
		if x < b.minX or x > b.maxX or z < b.minZ or z > b.maxZ then
			return false
		end
		local dw = math.sqrt((x - whale[1]) ^ 2 + (z - whale[3]) ^ 2)
		if dw < StarwhaleConfig.oddMinFromWhale or dw > StarwhaleConfig.oddRadius then
			return false
		end
		for _, p in out do
			if math.sqrt((x - p[1]) ^ 2 + (z - p[3]) ^ 2) < spacing then
				return false
			end
		end
		return true
	end

	local attempts = 0
	while #out < count and attempts < 400 do
		attempts += 1
		local angle = rng:range(0, math.pi * 2)
		local dist = rng:range(StarwhaleConfig.oddMinFromWhale, StarwhaleConfig.oddRadius)
		local x, z = whale[1] + math.cos(angle) * dist, whale[3] + math.sin(angle) * dist
		if valid(x, z) then
			table.insert(out, { x, StarwhaleConfig.oddY, z })
		end
	end
	-- Cadangan deterministik (praktis tak terpakai): kisi kasar di dalam batas.
	local gx = 0
	while #out < count and gx < 400 do
		gx += 1
		local x = b.minX + (gx * 7.3) % (b.maxX - b.minX)
		local z = b.minZ + (gx * 13.1) % (b.maxZ - b.minZ)
		if valid(x, z) then
			table.insert(out, { x, StarwhaleConfig.oddY, z })
		end
	end
	return out
end

-- Jumlah Stardust dari satu pod (bilangan bulat stardustMin..stardustMax).
function StarwhaleMath.stardustRoll(rng: RNG.RNG): number
	return rng:int(StarwhaleConfig.stardustMin, StarwhaleConfig.stardustMax)
end

-- Validasi penawaran. Mengembalikan true, atau false + pesan galat (bahasa in-game).
-- egg: info telur target (nil bila tidak ada) untuk penawaran needsEgg.
function StarwhaleMath.validateOffer(
	offerId: any,
	stardust: number,
	egg: EggInfo?,
	targetUid: string?
): (boolean, string?)
	local offer = if type(offerId) == "string" then StarwhaleConfig.offerById[offerId] else nil
	if not offer then
		return false, "Unknown offer."
	end
	if offer.needsEgg then
		if targetUid == nil or egg == nil then
			return false, "Pick one of your placed eggs."
		end
		if egg.frozen then
			return false, "That egg is being stolen!"
		end
		if egg.loc ~= "placed" then
			return false, "Place the egg in your Coop first."
		end
		if not MutationLogic.canAdd(egg.muts or {}, "Orbital") then
			return false, "This egg can't take that mutation."
		end
	end
	if stardust < offer.price then
		return false, `Not enough Stardust. You need {offer.price}.`
	end
	return true
end

-- Sudut panah kompas (derajat searah jarum jam dari arah pandang, -180..180).
-- (px,pz) pemain, (tx,tz) target, (lookX,lookZ) vektor pandang kamera (bidang XZ).
function StarwhaleMath.bearing(
	px: number,
	pz: number,
	tx: number,
	tz: number,
	lookX: number,
	lookZ: number
): number
	local dx, dz = tx - px, tz - pz
	local fl = math.sqrt(lookX * lookX + lookZ * lookZ)
	if fl < 1e-6 or (dx == 0 and dz == 0) then
		return 0
	end
	local fx, fz = lookX / fl, lookZ / fl
	-- kanan = (-fz, fx) pada koordinat Roblox (look -Z -> kanan +X)
	local forward = dx * fx + dz * fz
	local right = dx * -fz + dz * fx
	return math.deg(math.atan2(right, forward))
end

-- Selang kedip bip (detik): makin dekat makin cepat.
function StarwhaleMath.blinkInterval(distance: number): number
	local t = math.clamp(distance / StarwhaleConfig.blinkFarDistance, 0, 1)
	return StarwhaleConfig.blinkFast + (StarwhaleConfig.blinkSlow - StarwhaleConfig.blinkFast) * t
end

return StarwhaleMath
