-- Jalankan: lune run tests/run
local process = require("@lune/process")

local specs = {
	{ "NumberFormat", require("./unit/NumberFormat.spec") },
	{ "Formulas", require("./unit/Formulas.spec") },
	{ "RateLimiter", require("./unit/RateLimiter.spec") },
	{ "RNG", require("./unit/RNG.spec") },
	{ "Check", require("./unit/Check.spec") },
	{ "Maid", require("./unit/Maid.spec") },
	{ "Creatures", require("./unit/Creatures.spec") },
	{ "Progression", require("./unit/Progression.spec") },
	{ "WeightRoll", require("./unit/WeightRoll.spec") },
	{ "MutationLogic", require("./unit/MutationLogic.spec") },
	{ "PetMath", require("./unit/PetMath.spec") },
	{ "EggRoll", require("./unit/EggRoll.spec") },
	{ "FuseLogic", require("./unit/FuseLogic.spec") },
	{ "PipePuzzle", require("./unit/PipePuzzle.spec") },
	{ "NestLayout", require("./unit/NestLayout.spec") },
	{ "AntiExploitMath", require("./unit/AntiExploitMath.spec") },
	{ "GuardianChase", require("./unit/GuardianChase.spec") },
	{ "PvpRules", require("./unit/PvpRules.spec") },
}

local failed, total = 0, 0

local t = {}
function t.eq(actual, expected, label)
	total += 1
	if actual ~= expected then
		failed += 1
		print(`  FAIL {label or "?"}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end
function t.near(actual, expected, tol, label)
	total += 1
	if math.abs(actual - expected) > tol then
		failed += 1
		print(`  FAIL {label or "?"}: expected ~{expected}, got {actual}`)
	end
end
function t.truthy(v, label)
	total += 1
	if not v then
		failed += 1
		print(`  FAIL {label or "?"}: expected truthy`)
	end
end

for _, spec in specs do
	print(`[{spec[1]}]`)
	spec[2](t)
end

print(`\n{total - failed}/{total} assertion lulus`)
if failed > 0 then
	process.exit(1)
end
