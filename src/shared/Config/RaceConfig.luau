--!strict
-- Konfigurasi Dash Derby (docs/PLAN.md 4.10, docs/CHANGES.md #13). Murni angka/teks (Lune-testable).

local RaceConfig = {}

-- Jadwal (detik waktu-game).
RaceConfig.intervalSeconds = 1200 -- jeda antar race (Idle)
RaceConfig.countdownSeconds = 180 -- "Race in 2:54"
RaceConfig.openSeconds = 300 -- "Race open! 4:52"
RaceConfig.podiumSeconds = 15 -- fase Closed (podium tampil)
RaceConfig.broadcastEvery = 5 -- siaran RaceState berkala (detik)

-- Pemilihan zona.
RaceConfig.maxZone = 12
RaceConfig.minZone = 2
RaceConfig.speedHeadroom = 4 -- zona layak jika recSpeed <= 4x speed efektif tertinggi online

-- Lintasan.
RaceConfig.checkpointCount = 6 -- gerbang index 1..6; 0 = start; 7 = finish
RaceConfig.gateInset = 12 -- jarak start dari awal zona dan finish dari akhir zona
RaceConfig.gateHeight = 14 -- tinggi cincin neon
RaceConfig.pillarWidth = 3
RaceConfig.courseName = "DashDerbyCourse"
RaceConfig.gateColor = { 255, 214, 64 }
RaceConfig.startColor = { 110, 205, 120 }
RaceConfig.finishColor = { 255, 255, 255 }

-- Deteksi (waktu nyata).
RaceConfig.speedTolerance = 1.5 -- pengali WalkSpeed untuk batas jarak wajar antar sampel (cegah teleport)

-- Hadiah.
RaceConfig.baseTrophiesPerZone = 50
RaceConfig.rankMultipliers = { 4, 3, 2 } -- peringkat 1/2/3
RaceConfig.recordBonusPerZone = 25

RaceConfig.lockedMessage = "Eggs are locked during the race!"
RaceConfig.announcePrefix = "A race has appeared in "
RaceConfig.announceSuffix = "!"

return RaceConfig
