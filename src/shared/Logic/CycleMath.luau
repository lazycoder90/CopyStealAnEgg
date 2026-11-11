--!strict
-- Matematika siklus siang/malam (murni, tanpa Roblox). Semua waktu dalam detik waktu-game.

local EventsConfig = require("../Config/EventsConfig")

export type State = "Day" | "Night"

local CycleMath = {}

local cfg = EventsConfig.dayNight

function CycleMath.duration(state: State): number
	return if state == "Night" then cfg.nightSeconds else cfg.daySeconds
end

function CycleMath.other(state: State): State
	return if state == "Night" then "Day" else "Night"
end

-- Memajukan fase sebesar dt. Mengembalikan state akhir, sisa waktu, dan daftar fase yang DIMASUKI
-- (berurutan; kosong bila tidak ada pergantian). dt besar (timeScale tinggi) ditangani berulang.
function CycleMath.advance(state: State, remaining: number, dt: number): (State, number, { State })
	local entered: { State } = {}
	local left = remaining - dt
	local guard = 0
	while left <= 0 and guard < 1000 do
		guard += 1
		state = CycleMath.other(state)
		table.insert(entered, state)
		left += CycleMath.duration(state)
	end
	return state, left, entered
end

-- Detik sejak fase dimulai.
function CycleMath.elapsed(state: State, remaining: number): number
	return math.clamp(CycleMath.duration(state) - remaining, 0, CycleMath.duration(state))
end

-- 0 = terang penuh, 1 = gelap penuh. Naik lembut di awal malam, turun lembut di awal siang.
function CycleMath.darkness(state: State, remaining: number): number
	local t = math.clamp(CycleMath.elapsed(state, remaining) / cfg.rampSeconds, 0, 1)
	return if state == "Night" then t else 1 - t
end

-- Lighting.ClockTime dari darkness (14 -> 24 saat gelap; mod 24 oleh pemanggil).
function CycleMath.clockTime(darkness: number): number
	return (cfg.dayClockTime + (cfg.nightClockTime - cfg.dayClockTime) * darkness) % 24
end

-- Teks sisa waktu: "4m 19s" atau "45s" (dibulatkan ke atas).
function CycleMath.format(seconds: number): string
	local total = math.max(0, math.ceil(seconds - 1e-9))
	local m = total // 60
	local s = total % 60
	if m > 0 then
		return `{m}m {s}s`
	end
	return `{s}s`
end

-- Label BigCountdown pada detik terakhir sebelum pergantian ("Night in 9"); nil jika masih jauh.
function CycleMath.countdownLabel(state: State, remaining: number): string?
	if remaining > cfg.countdownSeconds or remaining <= 0 then
		return nil
	end
	local n = math.ceil(remaining - 1e-9)
	return `{CycleMath.other(state)} in {n}`
end

-- Pengali pertumbuhan global untuk fase (nil = tidak ada pengali).
function CycleMath.growthMultiplier(state: State): number?
	return if state == "Night" then cfg.nightGrowthMultiplier else nil
end

-- Format m:ss untuk chip Egg Reset.
function CycleMath.formatClock(seconds: number): string
	local total = math.max(0, math.ceil(seconds - 1e-9))
	return string.format("%d:%02d", total // 60, total % 60)
end

return CycleMath
