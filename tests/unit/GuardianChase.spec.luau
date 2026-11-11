local GuardianChase = require("../../src/shared/Logic/GuardianChase")
local GuardianConfig = require("../../src/shared/Config/GuardianConfig")
local Layout = require("../../src/shared/Config/Layout")
local Formulas = require("../../src/shared/Logic/Formulas")
local Zones = require("../../src/shared/Config/Zones")

local HEARTH = Layout.hearthLineZ

local function params(speed, radius)
	return { speed = speed, catchRadius = radius or 7, hearthLineZ = HEARTH }
end

return function(t)
	-- config
	for zone = 1, 12 do
		local x, z = GuardianConfig.home(zone)
		t.eq(x, 0, `home x zona {zone}`)
		t.eq(z, Layout.zoneZEnd(zone) - 62, `home z zona {zone}`)
		t.eq(Layout.zoneAtZ(z), zone, `home di dalam zona {zone}`)
	end
	t.near(GuardianConfig.catchRadius(20), 9, 1e-9, "catchRadius walk 20")
	t.near(GuardianConfig.catchRadius(170), 24, 1e-9, "catchRadius walk 170")
	t.eq(GuardianConfig.minZ(), HEARTH + 4, "minZ")

	-- gerak konstan
	local s = { x = 0, z = 400, mode = "Chase" }
	local target = { x = 0, z = 200 }
	local s2, caught = GuardianChase.step(s, target, 0.5, params(20))
	t.near(s2.z, 390, 1e-9, "maju 10 stud")
	t.eq(caught, false, "belum tertangkap")
	t.eq(s2.mode, "Chase", "mode dipertahankan")
	t.eq(s.z, 400, "state lama tidak dimutasi")

	-- diagonal: kecepatan tetap
	local d, _ = GuardianChase.moveToward({ x = 0, z = 300 }, 30, 340, 1, params(10))
	t.near(GuardianChase.distance({ x = 0, z = 300 }, d), 10, 1e-9, "langkah diagonal = speed*dt")

	-- tertangkap dalam radius
	local _, c1 = GuardianChase.step({ x = 0, z = 210 }, { x = 0, z = 200 }, 0.1, params(20, 9))
	t.eq(c1, true, "tertangkap (radius)")

	-- overshoot-safe: dt besar tidak melewati target
	local o, oc = GuardianChase.step({ x = 0, z = 400 }, { x = 5, z = 300 }, 100, params(170, 7))
	t.near(o.z, 300, 1e-9, "overshoot berhenti di target z")
	t.near(o.x, 5, 1e-9, "overshoot berhenti di target x")
	t.eq(oc, true, "overshoot -> tertangkap")

	-- kecepatan sampai 170 stud/s, banyak langkah, tidak pernah melewati target
	local pos = { x = 0, z = 1000, mode = "Chase" }
	local tgt = { x = 10, z = 500 }
	local ever = false
	for _ = 1, 400 do
		local nextPos, hit = GuardianChase.step(pos, tgt, 1 / 60, params(170, 24))
		t.truthy(nextPos.z >= tgt.z - 24 - 1e-6, "tidak melewati target (speed 170)")
		pos = nextPos
		if hit then
			ever = true
			break
		end
	end
	t.truthy(ever, "speed 170 akhirnya menangkap")

	-- dt nol dan negatif
	local z0 = GuardianChase.step({ x = 0, z = 300 }, { x = 0, z = 100 }, 0, params(20))
	t.eq(z0.z, 300, "dt=0 diam")
	local zn = GuardianChase.step({ x = 0, z = 300 }, { x = 0, z = 100 }, -1, params(20))
	t.eq(zn.z, 300, "dt negatif diam")

	-- clamp Hearth Line: target di hub, guardian berhenti di hearth+4
	local g = { x = 0, z = 200, mode = "Chase" }
	local hubTarget = { x = 0, z = 50 }
	for _ = 1, 200 do
		g = GuardianChase.step(g, hubTarget, 0.1, params(100, 7))
		t.truthy(g.z >= HEARTH + 4 - 1e-9, "tidak di bawah hearth+4")
	end
	t.near(g.z, HEARTH + 4, 1e-9, "berhenti tepat di hearth+4")

	-- clamp dengan dt sangat besar
	local big = GuardianChase.step({ x = 0, z = 500 }, { x = 0, z = -500 }, 1e6, params(170, 7))
	t.near(big.z, HEARTH + 4, 1e-9, "dt besar tetap di hearth+4")
	-- minZ lebih ketat dihormati, minZ lebih longgar ditolak
	local strict = GuardianChase.moveToward(
		{ x = 0, z = 500 },
		0,
		0,
		1e6,
		{ speed = 10, catchRadius = 7, hearthLineZ = HEARTH, minZ = 200 }
	)
	t.near(strict.z, 200, 1e-9, "minZ lebih ketat")
	local loose = GuardianChase.moveToward(
		{ x = 0, z = 500 },
		0,
		0,
		1e6,
		{ speed = 10, catchRadius = 7, hearthLineZ = HEARTH, minZ = 0 }
	)
	t.near(loose.z, HEARTH + 4, 1e-9, "minZ tidak boleh melewati Hearth Line")
	-- start di bawah batas langsung dikoreksi
	local fix = GuardianChase.moveToward({ x = 0, z = 100 }, 0, 100, 1, params(10))
	t.near(fix.z, HEARTH + 4, 1e-9, "posisi di bawah batas dikoreksi")

	-- kecepatan guardian zona nyata
	for zone = 1, 12 do
		local walk = Formulas.walkSpeed(Zones.get(zone).guardianSpeedStat)
			* GuardianConfig.chaseSpeedFactor
		t.truthy(walk >= 16 and walk <= 170 * 1.05 + 1e-9, `kecepatan guardian zona {zone} wajar`)
	end

	-- kembali ke rumah
	local home = { x = 0, z = 388 }
	local r = { x = 0, z = 200, mode = "Return" }
	local arrived = false
	for _ = 1, 400 do
		r, arrived = GuardianChase.moveToward(r, home.x, home.z, 0.1, params(12))
		if arrived then
			break
		end
	end
	t.eq(arrived, true, "tiba di rumah")
	t.near(r.z, 388, 1e-9, "tepat di rumah")

	-- shouldReturn
	local ctx = {
		target = { x = 0, z = 300 },
		targetCarrying = true,
		hearthLineZ = HEARTH,
		homeX = 0,
		homeZ = 388,
		leash = 700,
		chaseTime = 5,
		maxChaseSeconds = 25,
	}
	local st = { x = 0, z = 380 }
	local ret = GuardianChase.shouldReturn(st, ctx)
	t.eq(ret, false, "tetap mengejar")
	ctx.target = { x = 0, z = HEARTH - 1 }
	local r2, why2 = GuardianChase.shouldReturn(st, ctx)
	t.eq(r2, true, "target lewat Hearth Line")
	t.eq(why2, "crossed_hearth", "alasan hearth")
	ctx.target = { x = 0, z = HEARTH }
	t.eq(GuardianChase.shouldReturn(st, ctx), false, "tepat di garis belum dianggap lewat")
	ctx.target = { x = 0, z = 300 }
	ctx.targetCarrying = false
	local _, why3 = GuardianChase.shouldReturn(st, ctx)
	t.eq(why3, "target_dropped", "telur dijatuhkan")
	ctx.targetCarrying = true
	ctx.target = nil
	local _, why4 = GuardianChase.shouldReturn(st, ctx)
	t.eq(why4, "target_gone", "target hilang")
	ctx.target = { x = 0, z = 300 }
	local _, why5 = GuardianChase.shouldReturn({ x = 0, z = 388 + 701 }, ctx)
	t.eq(why5, "leash", "melewati leash")
	t.eq(GuardianChase.shouldReturn({ x = 0, z = 388 + 700 }, ctx), false, "tepat di leash belum")
	ctx.chaseTime = 25.1
	local _, why6 = GuardianChase.shouldReturn(st, ctx)
	t.eq(why6, "timeout", "waktu kejar habis")
	ctx.chaseTime = 25
	t.eq(GuardianChase.shouldReturn(st, ctx), false, "tepat 25 detik belum")
end
