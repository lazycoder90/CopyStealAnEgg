--!strict
-- Validator argumen remote. Setiap validator: (...any) -> boolean.
-- Pakai Check.args(v1, v2, ...) untuk membuat validator remote.
-- Kolom yang boleh kosong dibungkus Check.optional(v).

local Check = {}

export type Validator = (any) -> boolean

local OPTIONAL = {}

function Check.finite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Check.num(min: number, max: number): Validator
	return function(v)
		return Check.finite(v) and v >= min and v <= max
	end
end

function Check.int(min: number, max: number): Validator
	return function(v)
		return Check.finite(v) and v % 1 == 0 and v >= min and v <= max
	end
end

function Check.bool(v: any): boolean
	return type(v) == "boolean"
end

function Check.str(maxLen: number): Validator
	return function(v)
		return type(v) == "string" and #v <= maxLen
	end
end

-- uid: GUID pendek atau id spesies; hanya huruf, angka, '-' dan '_'.
function Check.uid(v: any): boolean
	return type(v) == "string" and #v >= 1 and #v <= 40 and string.match(v, "^[%w%-_]+$") ~= nil
end

function Check.enum(list: { string }): Validator
	local set = {}
	for _, item in list do
		set[item] = true
	end
	return function(v)
		return type(v) == "string" and set[v] == true
	end
end

function Check.vec3(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	return Check.finite(vec.X) and Check.finite(vec.Y) and Check.finite(vec.Z)
end

-- Array murni (indeks 1..n berurutan) berisi uid unik, panjang 1..maxLen. Dipakai Sell/Fuse.
function Check.uidList(maxLen: number): Validator
	return function(v)
		if type(v) ~= "table" then
			return false
		end
		local count = 0
		for _ in v do
			count += 1
		end
		if count < 1 or count > maxLen or #v ~= count then
			return false
		end
		local seen = {}
		for i = 1, count do
			local item = v[i]
			if not Check.uid(item) or seen[item] then
				return false
			end
			seen[item] = true
		end
		return true
	end
end

-- Grid bilangan bulat rows x cols (array of array), tiap nilai di [min, max]. Dipakai SubmitRelay (rotasi 5x5).
function Check.intGrid(rows: number, cols: number, min: number, max: number): Validator
	local isInt = Check.int(min, max)
	return function(v)
		if type(v) ~= "table" then
			return false
		end
		local rowCount = 0
		for _ in v do
			rowCount += 1
		end
		if rowCount ~= rows or #v ~= rows then
			return false
		end
		for r = 1, rows do
			local row = v[r]
			if type(row) ~= "table" then
				return false
			end
			local colCount = 0
			for _ in row do
				colCount += 1
			end
			if colCount ~= cols or #row ~= cols then
				return false
			end
			for c = 1, cols do
				if not isInt(row[c]) then
					return false
				end
			end
		end
		return true
	end
end

function Check.optional(validator: Validator): Validator
	local wrapped: any = function(v)
		return v == nil or validator(v)
	end
	return setmetatable({}, {
		__call = function(_, v)
			return wrapped(v)
		end,
		__index = { [OPTIONAL] = true },
	}) :: any
end

local function isOptional(validator: any): boolean
	if type(validator) == "table" then
		return validator[OPTIONAL] == true
	end
	return false
end

-- Membuat validator untuk seluruh daftar argumen remote. Argumen lebih banyak dari validator ditolak.
function Check.args(...: Validator): (...any) -> boolean
	local validators = { ... }
	local count = select("#", ...)
	return function(...)
		local argc = select("#", ...)
		if argc > count then
			return false
		end
		local args = { ... }
		for i = 1, count do
			local v = validators[i]
			local value = args[i]
			if value == nil then
				if not isOptional(v) then
					return false
				end
			elseif not v(value) then
				return false
			end
		end
		return true
	end
end

return Check
