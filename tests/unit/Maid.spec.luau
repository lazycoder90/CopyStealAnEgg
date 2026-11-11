local Maid = require("../../src/shared/Util/Maid")

return function(t)
	local log = {}
	local maid = Maid.new()
	maid:Give(function()
		table.insert(log, "fn1")
	end)
	maid:Give({
		Disconnect = function()
			table.insert(log, "disc")
		end,
	})
	maid:Give({
		Destroy = function()
			table.insert(log, "destroy")
		end,
	})
	maid:Give(function()
		table.insert(log, "fn2")
	end)
	maid:Clean()
	t.eq(table.concat(log, ","), "fn2,destroy,disc,fn1", "urutan terbalik")

	-- Clean kedua kali tidak melakukan apa-apa
	maid:Clean()
	t.eq(#log, 4, "idempoten")

	-- Task yang error tidak menghentikan pembersihan lain
	local m2 = Maid.new()
	local ran = false
	m2:Give(function()
		ran = true
	end)
	m2:Give(function()
		error("boom")
	end)
	m2:Clean()
	t.truthy(ran, "error satu task tidak menghalangi lainnya")

	-- Give mengembalikan task; Destroy = Clean
	local m3 = Maid.new()
	local n = 0
	local fn = m3:Give(function()
		n += 1
	end)
	t.eq(type(fn), "function", "Give mengembalikan task")
	m3:Destroy()
	t.eq(n, 1, "Destroy membersihkan")
end
