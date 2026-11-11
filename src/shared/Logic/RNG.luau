--!strict
-- RNG deterministik (Park-Miller / MINSTD). Murni Luau sehingga identik di Lune dan Roblox.
-- Perkalian state * 48271 < 2^53 sehingga eksak pada double.

local MODULUS = 2147483647
local MULT = 48271

local RNG = {}
RNG.__index = RNG

export type RNG = typeof(setmetatable({} :: { state: number }, RNG))

function RNG.new(seed: number?): RNG
	local s = math.floor(math.abs(seed or os.time())) % MODULUS
	if s == 0 then
		s = 1
	end
	return setmetatable({ state = s }, RNG)
end

function RNG.reseed(self: RNG, seed: number)
	local s = math.floor(math.abs(seed)) % MODULUS
	self.state = if s == 0 then 1 else s
end

-- Float di [0, 1).
function RNG.next(self: RNG): number
	self.state = (self.state * MULT) % MODULUS
	return (self.state - 1) / (MODULUS - 1)
end

-- Bilangan bulat di [min, max] (inklusif).
function RNG.int(self: RNG, min: number, max: number): number
	return min + math.floor(self:next() * (max - min + 1))
end

-- Float di [min, max).
function RNG.range(self: RNG, min: number, max: number): number
	return min + self:next() * (max - min)
end

-- Distribusi normal (Box-Muller), mean 0 dan simpangan baku 1.
function RNG.normal(self: RNG): number
	local u1 = math.max(self:next(), 1e-12)
	local u2 = self:next()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- true dengan peluang p (0..1).
function RNG.chance(self: RNG, p: number): boolean
	return self:next() < p
end

-- Memilih indeks dari daftar bobot (bobot <= 0 tidak pernah terpilih).
function RNG.weighted(self: RNG, weights: { number }): number
	local total = 0
	for _, w in weights do
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return 1
	end
	local r = self:next() * total
	local acc = 0
	local last = 1
	for i, w in weights do
		if w > 0 then
			acc += w
			last = i
			if r < acc then
				return i
			end
		end
	end
	return last
end

function RNG.shuffle<T>(self: RNG, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return RNG
