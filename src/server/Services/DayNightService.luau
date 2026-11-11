--!nonstrict
-- DayNightService: siklus siang (240 dtk) / malam (90 dtk) dalam waktu-game (Clock.every1Hz).
-- Malam: pertumbuhan telur x30 (GrowthService.setGlobalMultiplier) dan peluang Moonlit sekali per malam
-- untuk tiap telur placed. Server mengatur Lighting; klien menerima remote DayNight {state, remaining}.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventsConfig = require(Shared.Config.EventsConfig)
local Mutations = require(Shared.Config.Mutations)
local CycleMath = require(Shared.Logic.CycleMath)
local MutationLogic = require(Shared.Logic.MutationLogic)
local RNG = require(Shared.Logic.RNG)
local Net = require(Shared.Net.Net)
local Check = require(Shared.Util.Check)

local Systems = script.Parent.Parent.Systems
local InvariantChecker = require(Systems.InvariantChecker)
local TestBridge = require(Systems.TestBridge)

local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local GrowthService = require(script.Parent.GrowthService)
local StateReplicator = require(script.Parent.StateReplicator)
local Clock = require(Systems.Clock)

local DayNightService = {}

local cfg = EventsConfig.dayNight
local GROWTH_KEY = "night"
local BASE = {} -- nilai Lighting siang (dibaca saat Start)
local NIGHT_AMBIENT = Color3.fromRGB(30, 38, 70)
local NIGHT_OUTDOOR = Color3.fromRGB(40, 50, 95)
local NIGHT_BRIGHTNESS = 0.6

local state: CycleMath.State = "Day"
local remaining: number = cfg.daySeconds
local rng = RNG.new(os.time())
local sinceBroadcast = 0
local lastPayload = nil

function DayNightService.setSeed(seed: number)
	rng:reseed(seed)
end

function DayNightService.getState(): (CycleMath.State, number)
	return state, remaining
end

local function payload()
	return { state = state, remaining = math.floor(remaining * 10 + 0.5) / 10 }
end

local function broadcast()
	sinceBroadcast = 0
	lastPayload = payload()
	Net.fireAll("DayNight", lastPayload)
end

-- Lighting menurut tingkat gelap (0..1); murah: 1 kali per detik.
local function applyLighting()
	local d = CycleMath.darkness(state, remaining)
	Lighting.ClockTime = CycleMath.clockTime(d)
	if BASE.ambient then
		Lighting.Ambient = BASE.ambient:Lerp(NIGHT_AMBIENT, d)
		Lighting.OutdoorAmbient = BASE.outdoor:Lerp(NIGHT_OUTDOOR, d)
		Lighting.Brightness = BASE.brightness + (NIGHT_BRIGHTNESS - BASE.brightness) * d
	end
end

local function applyPhase()
	GrowthService.setGlobalMultiplier(GROWTH_KEY, CycleMath.growthMultiplier(state))
	applyLighting()
end

-- Satu putaran Moonlit untuk satu pemain: tiap telur placed tak beku melempar SEKALI.
-- Mengembalikan jumlah telur yang mendapat Moonlit.
function DayNightService.rollMoonlit(userId: number): number
	local data = DataService.getByUserId(userId)
	if not data then
		return 0
	end
	local uids = {}
	for uid, egg in data.eggs do
		if egg.loc == "placed" and not GrowthService.isFrozen(userId, uid) then
			table.insert(uids, uid)
		end
	end
	table.sort(uids)
	local count = 0
	for _, uid in uids do
		local egg = data.eggs[uid]
		local hit = rng:chance(Mutations.moonlitChancePerNight)
		if hit and MutationLogic.canAdd(egg.muts, "Moonlit") then
			egg.muts = MutationLogic.add(egg.muts, "Moonlit")
			StateReplicator.set(userId, `eggs.{uid}.muts`, egg.muts)
			GrowthService.ensureModel(userId, uid)
			count += 1
		end
	end
	if count > 0 then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Net.fire("Notify", player, "Moonlit mutation applied!", "success")
		end
	end
	return count
end

local function rollAll()
	for _, entry in DataService.all() do
		DayNightService.rollMoonlit(entry.userId)
	end
end

-- Memaksa fase (admin /night, /day): timer fase dimulai ulang; durasi tidak berubah.
function DayNightService.force(newState: CycleMath.State, skipMoonlit: boolean?)
	state = newState
	remaining = CycleMath.duration(newState)
	applyPhase()
	broadcast()
	if newState == "Night" and not skipMoonlit then
		rollAll()
	end
end

-- Uji: pulihkan fase dan sisa waktu persis (tanpa Moonlit).
function DayNightService.restore(newState: CycleMath.State, newRemaining: number)
	state = newState
	remaining = math.clamp(newRemaining, 0.1, CycleMath.duration(newState))
	applyPhase()
	broadcast()
end

function DayNightService.tick(dt: number)
	local newState, newRemaining, entered = CycleMath.advance(state, remaining, dt)
	state, remaining = newState, newRemaining
	if #entered > 0 then
		applyPhase()
		broadcast()
		for _, phase in entered do
			if phase == "Night" then
				rollAll()
			end
		end
	else
		applyLighting()
		sinceBroadcast += dt
		if sinceBroadcast >= cfg.broadcastEvery then
			broadcast()
		end
	end
end

function DayNightService.Init()
	InvariantChecker.registerWorld("DayNight", function()
		local out = {}
		for _, entry in DataService.all() do
			local m = GrowthService.multiplier(entry.userId)
			if state == "Night" and m < cfg.nightGrowthMultiplier then
				table.insert(out, `malam tapi pengali tumbuh {m} < {cfg.nightGrowthMultiplier}`)
			elseif state == "Day" and m >= cfg.nightGrowthMultiplier then
				table.insert(out, `siang tapi pengali tumbuh {m}`)
			end
			break
		end
		if remaining <= 0 or remaining > CycleMath.duration(state) + 1e-6 then
			table.insert(out, `sisa waktu fase tidak valid: {remaining}`)
		end
		return out
	end)

	TestBridge.register("daynight.state", function()
		return { state = state, remaining = remaining }
	end)
	TestBridge.register("daynight.force", function(newState, skipMoonlit)
		DayNightService.force(newState, skipMoonlit)
		return true
	end)
	TestBridge.register("daynight.restore", function(newState, newRemaining)
		DayNightService.restore(newState, newRemaining)
		return true
	end)
	TestBridge.register("daynight.tick", function(dt)
		DayNightService.tick(dt)
		return { state = state, remaining = remaining }
	end)
	TestBridge.register("daynight.seed", function(seed)
		DayNightService.setSeed(seed)
		return true
	end)
	TestBridge.register("daynight.moonlit", DayNightService.rollMoonlit)
	TestBridge.register("daynight.lastPayload", function()
		return lastPayload
	end)

	AdminService.register("night", function()
		DayNightService.force("Night")
		return "Malam dipaksa (durasi tetap)"
	end)
	AdminService.register("day", function()
		DayNightService.force("Day")
		return "Siang dipaksa (durasi tetap)"
	end)
end

function DayNightService.Start()
	BASE.ambient = Lighting.Ambient
	BASE.outdoor = Lighting.OutdoorAmbient
	BASE.brightness = Lighting.Brightness
	applyPhase()
	Clock.every1Hz(DayNightService.tick)

	Net.on("ClientReady", Check.args(), function(player)
		Net.fire("DayNight", player, payload())
	end)
end

return DayNightService
