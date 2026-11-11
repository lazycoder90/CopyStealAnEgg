--!strict
-- Token bucket per key (mis. UserId). Clock diinjeksi supaya bisa dites.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Bucket = { tokens: number, t: number }
export type RateLimiter = typeof(setmetatable(
	{} :: { rate: number, clock: () -> number, buckets: { [any]: Bucket } },
	RateLimiter
))

function RateLimiter.new(ratePerSecond: number, clock: () -> number): RateLimiter
	return setmetatable({ rate = ratePerSecond, clock = clock, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.rate, t = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.rate, b.tokens + (now - b.t) * self.rate)
	b.t = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.clear(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
