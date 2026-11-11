--!nonstrict
-- Pemeriksa invarian data (hanya Studio): tiap 5 detik memeriksa kondisi yang HARUS selalu benar.
-- Pelanggaran dicatat sebagai error merah di Output. Service mendaftarkan pemeriksaannya sendiri:
--   InvariantChecker.register("nama", function(entry) return { "pesan pelanggaran", ... } end)
-- entry = { userId, data, player, virtual }

local RunService = game:GetService("RunService")

local InvariantChecker = {}

local checks = {}
local lastViolations = {}

function InvariantChecker.register(name: string, fn: (any) -> { string }?)
	checks[name] = fn
end

-- Pemeriksaan tingkat dunia (sekali per putaran, bukan per pemain): fn() -> { pesan }
local worldChecks = {}
function InvariantChecker.registerWorld(name: string, fn: () -> { string }?)
	worldChecks[name] = fn
end

local function finite(v): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Pemeriksaan dasar: mata uang finite dan >= 0; kunci pets/eggs bertipe string.
InvariantChecker.register("base", function(entry)
	local out = {}
	local data = entry.data
	for _, field in { "cash", "trophies", "stardust", "speedBase", "totalEarned" } do
		local v = data[field]
		if not finite(v) or v < 0 then
			table.insert(out, `{field} tidak valid: {tostring(v)}`)
		end
	end
	for _, bucket in { "pets", "eggs" } do
		for key in data[bucket] or {} do
			if type(key) ~= "string" then
				table.insert(out, `kunci {bucket} bukan string: {tostring(key)}`)
			end
		end
	end
	return out
end)

-- Menjalankan semua pemeriksaan. Mengembalikan daftar string pelanggaran.
function InvariantChecker.check(): { string }
	local DataService = require(script.Parent.Parent.Services.DataService)
	local violations = {}
	for name, fn in worldChecks do
		local ok, result = pcall(fn)
		if not ok then
			table.insert(violations, `[{name}] pemeriksa error: {result}`)
		elseif result then
			for _, message in result do
				table.insert(violations, `[{name}] {message}`)
			end
		end
	end
	for _, entry in DataService.all() do
		for name, fn in checks do
			local ok, result = pcall(fn, entry)
			if not ok then
				table.insert(violations, `[{name}] pemeriksa error: {result}`)
			elseif result then
				for _, message in result do
					table.insert(violations, `[{name}] user {entry.userId}: {message}`)
				end
			end
		end
	end
	lastViolations = violations
	return violations
end

function InvariantChecker.last(): { string }
	return lastViolations
end

function InvariantChecker.Start()
	if not RunService:IsStudio() then
		return
	end
	local counter = 0
	-- Memakai waktu nyata (Heartbeat), bukan Clock, agar tidak ikut dipercepat timeScale.
	RunService.Heartbeat:Connect(function(dt)
		counter += dt
		if counter < 5 then
			return
		end
		counter = 0
		for _, message in InvariantChecker.check() do
			task.spawn(error, "[Invariant] " .. message, 0)
		end
	end)
end

return InvariantChecker
