local Layout = require("../../src/shared/Config/Layout")
local RNG = require("../../src/shared/Logic/RNG")
local RaceConfig = require("../../src/shared/Config/RaceConfig")
local RaceMath = require("../../src/shared/Logic/RaceMath")
local Zones = require("../../src/shared/Config/Zones")

return function(t)
	local half = Layout.laneWidth / 2

	-- posisi gerbang: start = awal+12, finish = akhir-12, merata, 8 gerbang
	t.eq(RaceMath.gateCount, 8, "8 gerbang")
	t.eq(RaceMath.gateZ(1, 0), Layout.zoneZStart(1) + 12, "start z")
	t.eq(RaceMath.gateZ(1, 7), Layout.zoneZEnd(1) - 12, "finish z")
	local gap = RaceMath.gateZ(3, 1) - RaceMath.gateZ(3, 0)
	for i = 1, 7 do
		t.near(RaceMath.gateZ(3, i) - RaceMath.gateZ(3, i - 1), gap, 1e-9, `jarak merata {i}`)
	end

	-- segmen vs bidang gerbang
	local gz = 100
	t.near(RaceMath.crossing(0, 90, 0, 110, gz, half) :: number, 0.5, 1e-9, "tembus tengah")
	t.eq(RaceMath.crossing(0, 110, 0, 90, gz, half), nil, "mundur diabaikan")
	t.eq(RaceMath.crossing(0, 90, 0, 99, gz, half), nil, "tidak sampai")
	t.eq(RaceMath.crossing(0, 100, 0, 110, gz, half), nil, "mulai tepat di bidang")
	t.truthy(RaceMath.crossing(0, 90, 0, 100, gz, half) ~= nil, "berakhir tepat di bidang")
	t.eq(RaceMath.crossing(70, 90, 70, 110, gz, half), nil, "di luar lebar lane")
	-- diagonal: x berpotongan di dalam lane walau ujungnya di luar
	t.truthy(RaceMath.crossing(-80, 90, 50, 110, gz, half) ~= nil, "diagonal masuk lane")
	t.eq(RaceMath.crossing(-80, 90, -61, 110, gz, half), nil, "diagonal keluar lane")

	-- progres berurutan
	local function seg(z0, z1)
		return RaceMath.crossings(1, 0, z0, 0, z1, half)
	end
	local last = -1
	local events
	-- checkpoint 1 sebelum start: diabaikan
	last, events = RaceMath.advance(last, seg(RaceMath.gateZ(1, 1) - 3, RaceMath.gateZ(1, 1) + 3))
	t.eq(last, -1, "cp tanpa start diabaikan")
	t.eq(#events, 0, "tanpa kejadian")
	-- start
	last, events = RaceMath.advance(last, seg(RaceMath.gateZ(1, 0) - 3, RaceMath.gateZ(1, 0) + 3))
	t.eq(last, 0, "start sah")
	t.eq(events[1].kind, "start", "kejadian start")
	-- loncat ke cp3: diabaikan
	last = RaceMath.advance(last, seg(RaceMath.gateZ(1, 3) - 3, RaceMath.gateZ(1, 3) + 3))
	t.eq(last, 0, "loncat cp diabaikan")
	-- cp1, cp2 berurutan
	for i = 1, 6 do
		last, events =
			RaceMath.advance(last, seg(RaceMath.gateZ(1, i) - 3, RaceMath.gateZ(1, i) + 3))
		t.eq(last, i, `cp{i}`)
		t.eq(events[1].kind, "checkpoint", `kind cp{i}`)
	end
	-- mundur melewati cp6 tidak mengubah
	local backLast = RaceMath.advance(last, seg(RaceMath.gateZ(1, 6) + 3, RaceMath.gateZ(1, 6) - 3))
	t.eq(backLast, 6, "mundur diabaikan")
	last, events = RaceMath.advance(last, seg(RaceMath.gateZ(1, 7) - 3, RaceMath.gateZ(1, 7) + 3))
	t.eq(events[1].kind, "finish", "finish")
	t.eq(last, -1, "reset setelah finish")
	-- satu segmen panjang menembus semua gerbang: semua sah berurutan
	local long = RaceMath.crossings(1, 0, 150, 0, 460, half)
	t.eq(#long, 8, "segmen panjang menembus 8 gerbang")
	local l2, ev2 = RaceMath.advance(-1, long)
	t.eq(l2, -1, "segmen panjang selesai")
	t.eq(ev2[#ev2].kind, "finish", "segmen panjang finish")
	-- start ulang di tengah percobaan me-restart
	local mid = RaceMath.advance(4, seg(RaceMath.gateZ(1, 0) - 3, RaceMath.gateZ(1, 0) + 3))
	t.eq(mid, 0, "start ulang")

	-- peringkat
	local ranked = RaceMath.rank({
		{ userId = 3, time = 20 },
		{ userId = 1, time = 12.5 },
		{ userId = 2, time = 12.5 },
	})
	t.eq(ranked[1].userId, 1, "seri: id kecil dulu")
	t.eq(ranked[2].userId, 2, "peringkat 2")
	t.eq(ranked[3].userId, 3, "peringkat 3")

	-- trophy: contoh PLAN +2,025 = zona 9 juara 1 + rekor
	t.eq(RaceMath.trophies(9, 1, true), 2025, "zona 9 juara 1 rekor = 2025")
	t.eq(RaceMath.trophies(1, 1, false), 200, "zona 1 juara 1")
	t.eq(RaceMath.trophies(2, 2, false), 300, "zona 2 juara 2")
	t.eq(RaceMath.trophies(2, 3, false), 200, "zona 2 juara 3")
	t.eq(RaceMath.trophies(2, 4, false), 100, "peringkat 4 dasar saja")
	t.eq(RaceMath.trophies(3, 5, true), 150 + 75, "rekor tambahan")
	t.truthy(RaceMath.beatsRecord(10, nil), "tanpa rekor lama")
	t.truthy(RaceMath.beatsRecord(10, 11), "lebih cepat")
	t.eq(RaceMath.beatsRecord(11, 11), false, "sama tidak memecahkan")

	-- zona layak
	t.eq(RaceMath.maxZoneFor(0), 2, "minimal 2")
	t.eq(RaceMath.maxZoneFor(1e3), 2, "speed 1e3: 4e3 < 8e3 -> zona 2")
	t.eq(RaceMath.maxZoneFor(2e3), 3, "speed 2e3: 8e3 <= 8e3 -> zona 3")
	t.eq(RaceMath.maxZoneFor(1e12), RaceConfig.maxZone, "dibatasi 12")
	for _, zone in Zones.list do
		t.truthy(RaceMath.maxZoneFor(zone.recSpeed) >= math.min(zone.index, 12), "zona layak naik")
	end

	-- bobot condong ke zona tinggi dan pickZone dalam rentang
	local weights = RaceMath.zoneWeights(5)
	t.truthy(weights[5] > weights[1], "bobot tinggi lebih besar")
	local rng = RNG.new(7)
	local counts = {}
	for _ = 1, 4000 do
		local z = RaceMath.pickZone(5, rng)
		t.truthy(z >= 1 and z <= 5, "pickZone dalam rentang")
		counts[z] = (counts[z] or 0) + 1
	end
	t.truthy(counts[5] > counts[1] * 2, "zona 5 lebih sering dari 1")

	-- format
	t.eq(RaceMath.commas(2025), "2,025", "koma ribuan")
	t.eq(RaceMath.commas(50), "50", "tanpa koma")
	t.eq(RaceMath.commas(1234567), "1,234,567", "jutaan")
	t.eq(RaceMath.formatTime(12.345), "00:12.34", "format waktu")
	t.eq(RaceMath.formatTime(75.5), "01:15.50", "format menit")
	t.eq(RaceMath.formatTime(0), "00:00.00", "nol")
end
