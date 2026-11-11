local RateLimiter = require("../../src/shared/Logic/RateLimiter")

return function(t)
	local now = 0
	local rl = RateLimiter.new(2, function()
		return now
	end)

	t.eq(rl:allow("a"), true, "token 1")
	t.eq(rl:allow("a"), true, "token 2")
	t.eq(rl:allow("a"), false, "habis")
	t.eq(rl:allow("b"), true, "key lain terpisah")

	now = 0.5 -- +1 token
	t.eq(rl:allow("a"), true, "refill")
	t.eq(rl:allow("a"), false, "habis lagi")

	now = 100 -- refill penuh tapi tidak melebihi kapasitas
	t.eq(rl:allow("a"), true, "penuh 1")
	t.eq(rl:allow("a"), true, "penuh 2")
	t.eq(rl:allow("a"), false, "tidak melebihi kapasitas")

	rl:clear("a")
	t.eq(rl:allow("a"), true, "setelah clear")
end
