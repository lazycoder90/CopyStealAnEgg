local MonetizationConfig = require("../../src/shared/Config/MonetizationConfig")
local MonetizationMath = require("../../src/shared/Logic/MonetizationMath")

return function(t)
	-- tier Skip Growth
	t.eq(MonetizationMath.skipTier(0), 1, "0 dtk tier 1")
	t.eq(MonetizationMath.skipTier(299), 1, "299 dtk tier 1")
	t.eq(MonetizationMath.skipTier(300), 2, "300 dtk tier 2")
	t.eq(MonetizationMath.skipTier(1799), 2, "1799 tier 2")
	t.eq(MonetizationMath.skipTier(1800), 3, "1800 tier 3")
	t.eq(MonetizationMath.skipTier(7199), 3, "7199 tier 3")
	t.eq(MonetizationMath.skipTier(7200), 4, "7200 tier 4")
	t.eq(MonetizationMath.skipTier(28799), 4, "28799 tier 4")
	t.eq(MonetizationMath.skipTier(28800), 5, "8 jam tier 5")
	t.eq(MonetizationMath.skipTier(1e9), 5, "sangat lama tier 5")
	t.eq(MonetizationConfig.skipTiers[1].price, 9, "harga tier 1")
	t.eq(MonetizationConfig.skipTiers[5].price, 129, "harga tier 5")

	-- paket cash
	t.eq(MonetizationMath.cashPackAmount(10, 30), 18000, "30 menit x $10/s")
	t.eq(MonetizationMath.cashPackAmount(10, 120), 72000, "2 jam")
	t.eq(MonetizationMath.cashPackAmount(10, 480), 288000, "8 jam")
	t.eq(MonetizationMath.cashPackAmount(0, 30), 100, "minimal $100")
	t.eq(MonetizationMath.cashPackAmount(0 / 0, 30), 100, "NaN -> minimal")
	t.eq(MonetizationMath.compensationCash(10), 3000, "kompensasi 5 menit")

	-- pemangkasan receipts
	local receipts = {}
	for i = 1, 130 do
		receipts[tostring(i)] = 1000 + i
	end
	t.eq(MonetizationMath.pruneReceipts(receipts, 100), 30, "30 dihapus")
	local count = 0
	for _ in receipts do
		count += 1
	end
	t.eq(count, 100, "tersisa 100")
	t.eq(receipts["130"], 1130, "terbaru dipertahankan")
	t.eq(receipts["31"], 1031, "batas terbaru dipertahankan")
	t.eq(receipts["30"], nil, "yang lama dihapus")
	t.eq(MonetizationMath.pruneReceipts(receipts, 100), 0, "tidak ada yang dihapus lagi")

	-- imbang timestamp: PurchaseId lebih besar dianggap lebih baru
	local tie = { ["5"] = 10, ["6"] = 10, ["7"] = 10 }
	MonetizationMath.pruneReceipts(tie, 2)
	t.eq(tie["5"], nil, "imbang: yang kecil dihapus")
	t.eq(tie["7"], 10, "imbang: yang besar dipertahankan")

	-- hitung mundur
	t.eq(MonetizationMath.formatCountdown(0), "00:00:00", "nol")
	t.eq(MonetizationMath.formatCountdown(-5), "00:00:00", "negatif")
	t.eq(MonetizationMath.formatCountdown(3661), "01:01:01", "1 jam 1 menit 1 detik")
	t.eq(MonetizationMath.formatCountdown(90061), "1d 01:01:01", "1 hari")

	-- semua id config 0 dan kunci unik
	local seen = {}
	for _, g in MonetizationConfig.gamepasses do
		t.eq(g.id, 0, "id gamepass 0 " .. g.key)
		t.truthy(not seen[g.key], "kunci unik " .. g.key)
		seen[g.key] = true
	end
	for _, p in MonetizationConfig.products do
		t.eq(p.id, 0, "id produk 0 " .. p.key)
		t.truthy(not seen[p.key], "kunci unik " .. p.key)
		seen[p.key] = true
	end
end
