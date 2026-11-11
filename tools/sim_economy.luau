--!strict
-- Simulasi ekonomi pemain "rata-rata serakah" (docs/PLAN.md §3.12, §4.8, §4.15).
-- Jalankan: lune run tools/sim_economy
-- Deterministik (RNG.new(seed)). Keluaran berupa tabel markdown untuk docs/ECONOMY.md.

local process = require("@lune/process")
local Creatures = require("../src/shared/Config/Creatures")
local Constants = require("../src/shared/Config/Constants")
local Eggs = require("../src/shared/Config/Eggs")
local Mutations = require("../src/shared/Config/Mutations")
local Progression = require("../src/shared/Config/Progression")
local Rarities = require("../src/shared/Config/Rarities")
local Zones = require("../src/shared/Config/Zones")
local EggRoll = require("../src/shared/Logic/EggRoll")
local Formulas = require("../src/shared/Logic/Formulas")
local MutationLogic = require("../src/shared/Logic/MutationLogic")
local PetMath = require("../src/shared/Logic/PetMath")
local RNG = require("../src/shared/Logic/RNG")

-- ===== Asumsi (salin ke docs/ECONOMY.md) =====
local DEFAULTS = {
	seed = 20260101,
	dt = 5, -- detik per langkah simulasi
	horizonHours = 80,
	activity = 0.75, -- porsi waktu pemain benar-benar bermain (sisanya baca UI, mati, loading)
	wheelShare = 0.5, -- porsi waktu bermain yang dijatah ke roda (sisanya lari ambil telur)
	wheelEfficiency = 0.8, -- porsi waktu di roda yang menghasilkan step (conveyor mendorong keluar)
	grabSeconds = 8, -- ambil telur (tahan 0.3s) + tempatkan + UI
	nestDistance = function(zone: number): number -- stud dari Coop ke nest rata-rata zona
		return 235 + 300 * (zone - 0.5)
	end,
	carrySpeedFactor = 1.0, -- carry tidak memperlambat
	successAtRec = 0.9, -- peluang bawa pulang jika speed >= recSpeed
	successBelowRec = 0.3, -- jika recSpeed/3 <= speed < recSpeed (guardian sering menangkap)
	riskFloor = 1 / 3, -- pemain tidak pernah menjajal zona dengan speed < recSpeed * riskFloor
	failPenaltySeconds = 10, -- ragdoll + kembali
	grandCooldown = 600, -- Grand Nest hanya tiap Global Reset
	dayLength = 240,
	nightLength = 90,
	nightGrowth = 30,
	-- pengubah untuk menguji rekomendasi
	wheelGainMult = 1,
	wheelPriceMult = 1,
	wheelPriceRatio = 3, -- harga L = 500 * ratio^(L-1) (Formulas: 3)
	wheelGainRatio = 1.75, -- gain L = round(2 * ratio^(L-1)) (Formulas: 1.75)
	indexSpeedFactor = 0.02,
	incomeMult = 1, -- pengali global income pet
	recSpeedMult = 1, -- pengali recSpeed zona (uji pergeseran gerbang)
}

type Params = typeof(DEFAULTS)

type Egg = { speciesId: string, kg: number, muts: { string }, remaining: number, zone: number }
type Pet = { speciesId: string, income: number }

export type Result = {
	reach: { [number]: number },
	milestones: { { label: string, time: number } },
	snapshots: {
		{
			time: number,
			speed: number,
			income: number,
			wheel: number,
			pen: number,
			slots: number,
			zone: number,
		}
	},
}

local function simulate(overrides: { [string]: any }?): Result
	local p: any = table.clone(DEFAULTS)
	for k, v in overrides or {} do
		p[k] = v
	end
	local rng = RNG.new(p.seed)

	-- Status pemain
	local money = 0
	local speedBase = Constants.START_SPEED
	local wheelLevel = 1
	local penLevel = 1
	local equipSlots = Progression.startEquipSlots
	local plotExpansion = 0
	local trailIndex = 0 -- jumlah trail dibeli
	local eggs: { Egg } = {}
	local pets: { Pet } = {} -- hanya yang equip, terurut turun
	local discovered: { [string]: boolean } = {}
	local zoneFound: { [number]: number } = {}
	local completeZones = 0
	local tripTimer = 0
	local tripZone = 1
	local tripGrand = false
	local grandReadyAt: { [number]: number } = {}

	local cyc = p.dayLength + p.nightLength
	local avgGrowth = (p.dayLength + p.nightLength * p.nightGrowth) / cyc
	local expectedIncome: { [number]: number } = {}
	local expectedHatch: { [number]: number } = {}
	do
		local weights = Eggs.smallNestWeights
		local total = 0
		for _, w in weights do
			total += w
		end
		for z = 1, Zones.count do
			local inc, hatch = 0, 0
			for slot, w in weights do
				local c = Creatures.byZone[z][slot]
				inc += w / total * c.baseIncome
				hatch += w / total * Rarities.get(c.rarity).hatchBase * Zones.get(z).zoneFactor
			end
			expectedIncome[z], expectedHatch[z] = inc, hatch
		end
	end

	local result: Result = { reach = {}, milestones = {}, snapshots = {} }
	local function mark(label: string, t: number)
		table.insert(result.milestones, { label = label, time = t })
	end

	local function trailMult(): number
		if trailIndex == 0 then
			return 1
		end
		return Progression.trails[trailIndex].mult
	end
	local function effSpeed(): number
		return speedBase * trailMult()
	end
	local function income(): number
		local sum = 0
		for _, pet in pets do
			sum += pet.income
		end
		return sum * (1 + 0.02 * completeZones) * p.incomeMult
	end
	local function recSpeed(zone: number): number
		return Zones.get(zone).recSpeed * p.recSpeedMult
	end
	-- Zona terbaik menurut recSpeed (untuk statistik).
	local function bestZone(): number
		local best = 1
		local s = effSpeed()
		for z = 1, Zones.count do
			if s >= recSpeed(z) then
				best = z
			end
		end
		return best
	end

	-- Pemain serakah: pilih zona dengan nilai telur per detik tertinggi, memperhitungkan risiko
	-- tertangkap (successBelowRec) dan lamanya slot terpakai menunggu hatch.
	local function chooseZone(): number
		local s = effSpeed()
		local walk = Formulas.walkSpeed(s) * p.carrySpeedFactor
		local slots = Progression.eggSlotsFor(penLevel, plotExpansion)
		local bestZ, bestScore = 1, -1
		for z = 1, Zones.count do
			if s < recSpeed(z) * p.riskFloor then
				break
			end
			local succ = if s >= recSpeed(z) then p.successAtRec else p.successBelowRec
			local trip = p.grabSeconds + 2 * p.nestDistance(z) / walk
			local expectedTrip = trip + (1 - succ) / succ * (trip + p.failPenaltySeconds)
			local slotCycle = expectedHatch[z] / avgGrowth / slots
			local score = expectedIncome[z] / math.max(expectedTrip / p.activity, slotCycle)
			if score > bestScore then
				bestZ, bestScore = z, score
			end
		end
		return bestZ
	end

	local function equipPet(speciesId: string, inc: number)
		table.insert(pets, { speciesId = speciesId, income = inc })
		table.sort(pets, function(a, b)
			return a.income > b.income
		end)
		if #pets > equipSlots then
			local worst = table.remove(pets) :: Pet
			money += 100 * worst.income * p.incomeMult -- jual pet tak terpakai (sellPetValue)
		end
	end

	local function onHatch(egg: Egg, t: number)
		local c = Creatures.get(egg.speciesId)
		local muts = egg.muts
		local inc = PetMath.petIncome(egg.speciesId, egg.kg, muts)
		if not discovered[egg.speciesId] then
			discovered[egg.speciesId] = true
			money += c.baseIncome * 120
			speedBase += math.max(5, Zones.get(c.zone).recSpeed * p.indexSpeedFactor * c.slot)
			zoneFound[c.zone] = (zoneFound[c.zone] or 0) + 1
			if zoneFound[c.zone] == 8 then
				completeZones += 1
				mark(`Index zona {c.zone} lengkap`, t)
			end
		end
		equipPet(egg.speciesId, inc)
	end

	-- Pembelian serakah: selalu yang termurah yang tersedia.
	local function tryBuy(t: number)
		while true do
			local bestPrice, bestKind = math.huge, ""
			if wheelLevel < Progression.wheel.maxLevel then
				local price = 500 * p.wheelPriceRatio ^ (wheelLevel - 1) * p.wheelPriceMult
				if price < bestPrice then
					bestPrice, bestKind = price, "wheel"
				end
			end
			if equipSlots < Progression.maxEquipSlots then
				local price = Progression.equipSlotPrices[equipSlots + 1]
				if price < bestPrice then
					bestPrice, bestKind = price, "slot"
				end
			end
			if penLevel < Progression.maxPenLevel then
				local price = Progression.pen[penLevel + 1].price
				if price < bestPrice then
					bestPrice, bestKind = price, "pen"
				end
			end
			if trailIndex < #Progression.trails then
				local price = Progression.trails[trailIndex + 1].cashPrice
				if price < bestPrice then
					bestPrice, bestKind = price, "trail"
				end
			end
			if plotExpansion < 1 then
				local price = Progression.plotExpansion.price
				if price < bestPrice then
					bestPrice, bestKind = price, "plot"
				end
			end
			if bestKind == "" or money < bestPrice then
				return
			end
			money -= bestPrice
			if bestKind == "wheel" then
				wheelLevel += 1
				if wheelLevel % 5 == 0 and wheelLevel <= 40 then
					mark(`Wheel Lv{wheelLevel}`, t)
				end
			elseif bestKind == "slot" then
				equipSlots += 1
				mark(`Equip slot {equipSlots}`, t)
			elseif bestKind == "pen" then
				penLevel += 1
				mark(`Pen Lv{penLevel}`, t)
			elseif bestKind == "trail" then
				trailIndex += 1
				mark(`Trail {Progression.trails[trailIndex].name}`, t)
			else
				plotExpansion = 1
				mark("Plot expansion $1K", t)
			end
		end
	end

	local cycle = p.dayLength + p.nightLength
	local steps = math.floor(p.horizonHours * 3600 / p.dt)
	local reachedUpTo = 1
	result.reach[1] = 0
	local nextSnapshot = 0
	local dt = p.dt
	local moonStepChance = 1 - (1 - Mutations.moonlitChancePerNight) ^ (dt / p.nightLength)

	for step = 1, steps do
		local t = step * dt
		local isNight = (t % cycle) >= p.dayLength
		local growth = if isNight then p.nightGrowth else 1

		-- Income
		money += income() * dt

		-- Telur tumbuh
		local i = 1
		while i <= #eggs do
			local egg = eggs[i]
			egg.remaining -= dt * growth
			if isNight and not table.find(egg.muts, "Moonlit") and rng:chance(moonStepChance) then
				egg.muts = MutationLogic.add(egg.muts, "Moonlit")
			end
			if egg.remaining <= 0 then
				table.remove(eggs, i)
				onHatch(egg, t)
			else
				i += 1
			end
		end

		-- Aksi pemain
		local playerTime = dt * p.activity * (1 - p.wheelShare)
		local wheelTime = dt * p.activity * p.wheelShare
		local freeSlots = Progression.eggSlotsFor(penLevel, plotExpansion) - #eggs
		while playerTime > 0 do
			if tripTimer > 0 then
				local used = math.min(tripTimer, playerTime)
				tripTimer -= used
				playerTime -= used
				if tripTimer <= 0 then
					-- Trip selesai
					local zone = tripZone
					local s = effSpeed()
					local chance = if s >= recSpeed(zone) then p.successAtRec else p.successBelowRec
					if rng:chance(chance) then
						local egg = EggRoll.rollEgg(rng, zone, tripGrand, 1)
						table.insert(eggs, {
							speciesId = egg.speciesId,
							kg = egg.kg,
							muts = MutationLogic.rollOnHatch(rng, 1),
							remaining = egg.growTotal,
							zone = zone,
						})
					else
						tripTimer = 0
						playerTime = math.max(0, playerTime - p.failPenaltySeconds)
					end
				end
			elseif freeSlots > 0 and #eggs < Progression.eggSlotsFor(penLevel, plotExpansion) then
				-- Mulai trip baru
				local zone = chooseZone()
				tripZone = zone
				tripGrand = (grandReadyAt[zone] or 0) <= t and zone >= 3
				if tripGrand then
					grandReadyAt[zone] = t + p.grandCooldown
				end
				local walk = Formulas.walkSpeed(effSpeed()) * p.carrySpeedFactor
				tripTimer = p.grabSeconds + 2 * p.nestDistance(zone) / walk
				freeSlots -= 1
			else
				-- Di roda
				wheelTime += playerTime
				playerTime = 0
			end
		end
		if wheelTime > 0 then
			local steps_ = Progression.wheel.stepsPerSecond * wheelTime * p.wheelEfficiency
			speedBase += steps_ * math.floor(2 * p.wheelGainRatio ^ (wheelLevel - 1) + 0.5) * p.wheelGainMult
		end

		tryBuy(t)

		-- Gerbang zona
		local s = effSpeed()
		while reachedUpTo < Zones.count and s >= recSpeed(reachedUpTo + 1) do
			reachedUpTo += 1
			result.reach[reachedUpTo] = t
		end

		if t >= nextSnapshot then
			table.insert(result.snapshots, {
				time = t,
				speed = s,
				income = income(),
				wheel = wheelLevel,
				pen = penLevel,
				slots = equipSlots,
				zone = bestZone(),
			})
			if nextSnapshot < 3600 then
				nextSnapshot += 600
			elseif nextSnapshot < 12 * 3600 then
				nextSnapshot += 3600
			else
				nextSnapshot += 6 * 3600
			end
		end
	end
	return result
end

-- ===== Pelaporan =====
local function fmtTime(sec: number?): string
	if sec == nil then
		return "belum tercapai"
	end
	if sec < 90 then
		return string.format("%.0f dtk", sec)
	elseif sec < 5400 then
		return string.format("%.1f mnt", sec / 60)
	end
	return string.format("%.1f jam", sec / 3600)
end

local function fmtNum(n: number): string
	if n < 1000 then
		return string.format("%.3g", n)
	end
	local suffixes = { "K", "M", "B", "T", "Qa", "Qi", "Sx" }
	local e = math.floor(math.log10(n) / 3)
	local idx = math.min(e, #suffixes)
	return string.format("%.3g%s", n / 10 ^ (idx * 3), suffixes[idx])
end

local TARGETS = { [2] = 300, [5] = 2700, [9] = 21600, [12] = 108000 }

local function report(title: string, r: Result)
	print(`\n### {title}\n`)
	print("| Zona | recSpeed | Waktu tercapai | Target | Selisih |")
	print("|---|---|---|---|---|")
	for z = 1, Zones.count do
		local tgt = TARGETS[z]
		local reached = r.reach[z]
		local diff = ""
		if tgt and reached then
			diff = string.format("%+.0f%%", (reached / tgt - 1) * 100)
		end
		print(
			`| {z} | {fmtNum(Zones.get(z).recSpeed)} | {fmtTime(reached)} | {if tgt
				then fmtTime(tgt)
				else "-"} | {diff} |`
		)
	end
end

-- Rekomendasi (hasil penalaan; lihat docs/ECONOMY.md).
local RECOMMENDED = {
	wheelPriceRatio = 5.5, -- Formulas.wheelUpgradePrice: 3^(L-1) -> 5.5^(L-1)
	wheelPriceMult = 3, -- 500 -> 1500 di L1
	indexSpeedFactor = 0.0005, -- reward speed Index: recSpeed*0.02*slot -> recSpeed*0.0005*slot
}

local function printMilestones(r: Result)
	print("\n| Waktu | Kejadian |")
	print("|---|---|")
	for _, m in r.milestones do
		print(`| {fmtTime(m.time)} | {m.label} |`)
	end
end

local function printSnapshots(r: Result)
	print("\n| Waktu | Speed | Income/s | Wheel | Pen | Slot equip | Zona terbaik |")
	print("|---|---|---|---|---|---|---|")
	for _, s in r.snapshots do
		print(
			`| {fmtTime(s.time)} | {fmtNum(s.speed)} | {fmtNum(s.income)} | {s.wheel} | {s.pen} | {s.slots} | {s.zone} |`
		)
	end
end

local function main()
	local base = simulate()
	report("Baseline (konstanta saat ini)", base)
	print("\n#### Milestone baseline")
	printMilestones(base)
	print("\n#### Snapshot baseline")
	printSnapshots(base)

	local tuned = simulate(RECOMMENDED)
	report("Dengan rekomendasi", tuned)
	print("\n#### Milestone dengan rekomendasi")
	printMilestones(tuned)
	print("\n#### Snapshot dengan rekomendasi")
	printSnapshots(tuned)

	-- Sensitivitas asumsi (pada konstanta rekomendasi)
	local variants = {
		{ "rekomendasi (acuan)", {} },
		{ "activity 0.5", { activity = 0.5 } },
		{ "activity 1.0", { activity = 1.0 } },
		{ "wheelShare 0.3", { wheelShare = 0.3 } },
		{ "wheelShare 0.7", { wheelShare = 0.7 } },
		{ "wheelEfficiency 0.5", { wheelEfficiency = 0.5 } },
		{ "successAtRec 0.7", { successAtRec = 0.7 } },
		{ "riskFloor 1 (tak berani nekat)", { riskFloor = 1 } },
	}
	print("\n### Sensitivitas asumsi (konstanta rekomendasi)\n")
	print("| Varian | Z2 | Z5 | Z9 | Z12 |")
	print("|---|---|---|---|---|")
	for _, v in variants do
		local o: { [string]: any } = table.clone(RECOMMENDED)
		for k, x in v[2] :: any do
			o[k] = x
		end
		local r = simulate(o)
		print(
			`| {v[1]} | {fmtTime(r.reach[2])} | {fmtTime(r.reach[5])} | {fmtTime(r.reach[9])} | {fmtTime(
				r.reach[12]
			)} |`
		)
	end
end

-- Mode eksplorasi: lune run tools/sim_economy -- key=value ...  (cetak satu baris waktu tercapai)
local function explore(args: { string })
	local overrides: { [string]: any } = {}
	for _, a in args do
		local k, v = string.match(a, "^(%w+)=(.+)$")
		if k and v then
			overrides[k] = tonumber(v)
		end
	end
	local r = simulate(overrides)
	local parts = {}
	for z = 2, Zones.count do
		table.insert(parts, `z{z}={fmtTime(r.reach[z])}`)
	end
	print(table.concat(parts, "  "))
end

if #process.args > 0 then
	explore(process.args)
else
	main()
end
