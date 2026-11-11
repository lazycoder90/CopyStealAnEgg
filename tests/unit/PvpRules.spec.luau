local PvpRules = require("../../src/shared/Logic/PvpRules")

return function(t)
	-- Kerucut ayun: pandangan ke +Z.
	local function hit(dx, dz)
		return PvpRules.inSwingCone(dx, dz, 0, 1, PvpRules.panRange, PvpRules.panHalfAngle)
	end
	t.eq(hit(0, 5), true, "lurus di depan")
	t.eq(hit(0, 9), true, "tepat di batas jarak")
	t.eq(hit(0, 9.5), false, "di luar jarak")
	t.eq(hit(0, -5), false, "di belakang")
	t.eq(hit(5, 0), false, "samping 90 derajat")
	t.eq(hit(4, 4), true, "45 derajat")
	t.eq(hit(5, 1), false, "78 derajat di luar")
	t.eq(hit(5, 2), true, "68 derajat di dalam")
	t.eq(hit(0, 0), true, "jarak nol")
	t.eq(PvpRules.inSwingCone(3, 0, 0, 0, 9, 70), false, "look nol")
	t.eq(PvpRules.inSwingCone(0, 3, 0, 10, 9, 70), true, "look tidak ternormalisasi")

	-- Cooldown
	t.eq(PvpRules.cooldownReady(nil, 0, 1.2), true, "belum pernah")
	t.eq(PvpRules.cooldownReady(10, 10.5, 1.2), false, "masih cooldown")
	t.eq(PvpRules.cooldownReady(10, 11.2, 1.2), true, "tepat selesai")
	t.eq(PvpRules.cooldownReady(10, 12, 1.2), true, "lewat")

	-- Harga trap
	t.eq(PvpRules.trapCost(0), 10000, "minimal 10K")
	t.eq(PvpRules.trapCost(nil), 10000, "nil income")
	t.eq(PvpRules.trapCost(50), 10000, "6K di bawah minimum")
	t.eq(PvpRules.trapCost(1000), 120000, "2 menit income")
	t.eq(PvpRules.trapCost(0 / 0), 10000, "NaN aman")
	t.eq(PvpRules.trapCost(-5), 10000, "negatif aman")

	-- Batas trap dan durasi shield
	t.eq(PvpRules.maxTraps(1), 1, "pen 1")
	t.eq(PvpRules.maxTraps(5), 1, "pen 5")
	t.eq(PvpRules.maxTraps(6), 2, "pen 6")
	t.eq(PvpRules.maxTraps(11), 2, "pen 11")
	t.eq(PvpRules.shieldDuration(1), 60, "shield dasar")
	t.eq(PvpRules.shieldDuration(3), 60, "shield pen 3")
	t.eq(PvpRules.shieldDuration(4), 75, "shield pen 4")
	t.eq(PvpRules.shieldDuration(nil), 60, "shield nil")

	-- Geometri
	t.eq(PvpRules.inCircle(0, 70, 0, 70, 26), true, "pusat pad")
	t.eq(PvpRules.inCircle(26, 70, 0, 70, 26), true, "tepi pad")
	t.eq(PvpRules.inCircle(27, 70, 0, 70, 26), false, "di luar pad")
	t.eq(PvpRules.insideSquare(40, -40, 40), true, "sudut persegi")
	t.eq(PvpRules.insideSquare(41, 0, 40), false, "luar persegi")

	local x, z = PvpRules.pushOutside(10, 35, 40, 3)
	t.eq(x, 10, "dorong sisi +Z: x tetap")
	t.eq(z, 43, "dorong sisi +Z: z di luar pagar")
	x, z = PvpRules.pushOutside(-38, 5, 40, 3)
	t.eq(x, -43, "dorong sisi -X")
	t.eq(z, 5, "dorong sisi -X: z tetap")
	x, z = PvpRules.pushOutside(0, -39, 40, 3)
	t.eq(z, -43, "dorong sisi -Z")
	x, z = PvpRules.pushOutside(39, 0, 40, 3)
	t.eq(x, 43, "dorong sisi +X")
	x, z = PvpRules.pushOutside(60, 0, 40, 3)
	t.eq(x, 60, "sudah di luar: tidak berubah")
	t.eq(z, 0, "sudah di luar: z tidak berubah")
	x, z = PvpRules.pushOutside(5, 5, 40, 3)
	t.eq(PvpRules.insideSquare(x, z, 40), false, "hasil selalu di luar")
end
