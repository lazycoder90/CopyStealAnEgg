--!nonstrict
-- Satu-satunya pintu mutasi mata uang/stat numerik pemain. Menjaga nilai selalu finite dan >= 0
-- (NaN/inf akan merusak profil dan gagal disimpan) dan mereplikasi ke klien.

local DataService = require(script.Parent.DataService)
local StateReplicator = require(script.Parent.StateReplicator)

local CurrencyService = {}

local FIELDS = { cash = true, trophies = true, stardust = true, speedBase = true }
local MAX_VALUE = 1e300

local function finite(v): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function commit(userId: number, data, field: string, value: number)
	data[field] = value
	StateReplicator.set(userId, field, value)
end

function CurrencyService.get(userId: number, field: string): number?
	assert(FIELDS[field], "field mata uang tidak dikenal: " .. tostring(field))
	local data = DataService.getByUserId(userId)
	return data and data[field]
end

-- Menambah (amount >= 0). Mengembalikan false jika data tidak ada atau amount tidak valid.
function CurrencyService.add(userId: number, field: string, amount: number): boolean
	assert(FIELDS[field], "field mata uang tidak dikenal: " .. tostring(field))
	if not finite(amount) or amount < 0 then
		return false
	end
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	local value = math.min((data[field] or 0) + amount, MAX_VALUE)
	commit(userId, data, field, value)
	if field == "cash" then
		data.totalEarned = math.min((data.totalEarned or 0) + amount, MAX_VALUE)
	end
	return true
end

-- Mengurangi jika saldo cukup. Mengembalikan true jika berhasil.
function CurrencyService.trySpend(userId: number, field: string, amount: number): boolean
	assert(FIELDS[field], "field mata uang tidak dikenal: " .. tostring(field))
	if not finite(amount) or amount < 0 then
		return false
	end
	local data = DataService.getByUserId(userId)
	if not data or (data[field] or 0) < amount then
		return false
	end
	commit(userId, data, field, data[field] - amount)
	return true
end

-- Menetapkan nilai langsung (admin/tes/data migrasi). Nilai tidak valid ditolak.
function CurrencyService.set(userId: number, field: string, value: number): boolean
	assert(FIELDS[field], "field mata uang tidak dikenal: " .. tostring(field))
	if not finite(value) or value < 0 then
		return false
	end
	local data = DataService.getByUserId(userId)
	if not data then
		return false
	end
	commit(userId, data, field, math.min(value, MAX_VALUE))
	return true
end

return CurrencyService
