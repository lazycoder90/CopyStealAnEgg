--!strict
-- Matematika murni anti-exploit gerak (bisa dites di Lune).

local Formulas = require("./Formulas")

local TravelMath = {}

local FLOOR_SPEED = 16
local SAMPLE_FACTOR = 1.6
local SAMPLE_SLACK = 8
local TRAVEL_FACTOR = 1.5
local TRAVEL_SLACK = 20

-- Kecepatan maksimum sah dari stat speed (lantai 16).
function TravelMath.maxSpeed(effectiveSpeed: number): number
	return math.max(Formulas.walkSpeed(effectiveSpeed), FLOOR_SPEED)
end

-- Jarak horizontal maksimum antar dua sampel posisi (dt detik, nyata) dengan WalkSpeed tertentu.
function TravelMath.maxSampleDistance(walkSpeed: number, dt: number): number
	return math.max(walkSpeed, FLOOR_SPEED) * dt * SAMPLE_FACTOR + SAMPLE_SLACK
end

function TravelMath.samplePlausible(distance: number, walkSpeed: number, dt: number): boolean
	return distance <= TravelMath.maxSampleDistance(walkSpeed, dt)
end

-- Perjalanan jarak `distance` dalam `elapsed` detik masuk akal untuk kecepatan maksimum `maxSpeed`?
function TravelMath.plausible(distance: number, elapsed: number, maxSpeed: number): boolean
	return distance
		<= math.max(maxSpeed, FLOOR_SPEED) * math.max(elapsed, 0) * TRAVEL_FACTOR + TRAVEL_SLACK
end

return TravelMath
