--!nonstrict
-- Clock terpusat: satu loop Heartbeat untuk semua tick 1 Hz dan 10 Hz.
-- Callback menerima dt dalam "waktu game" (dikali timeScale; HANYA untuk ekonomi: growth, income,
-- timer event). Gerak guardian, anti-exploit, dan race memakai waktu nyata (os.clock / Heartbeat dt).
-- Clock.now() = os.time() + offset; semua cooldown berbasis waktu dinding memakai ini
-- supaya /advance di Studio ikut menggeser mereka.

local RunService = game:GetService("RunService")

local Clock = { timeScale = 1, offset = 0 }

local callbacks1, callbacks10 = {}, {}
local acc1, acc10 = 0, 0

function Clock.now(): number
	return os.time() + Clock.offset
end

-- Hanya Studio. Menggeser Clock.now() maju sejumlah detik.
function Clock.advance(seconds: number)
	Clock.offset += seconds
end

function Clock.every1Hz(fn: (dt: number) -> ())
	table.insert(callbacks1, fn)
end

function Clock.every10Hz(fn: (dt: number) -> ())
	table.insert(callbacks10, fn)
end

local function run(list, dt)
	for _, fn in list do
		task.spawn(function()
			local ok, err = pcall(fn, dt)
			if not ok then
				warn("[Clock] tick gagal:", err)
			end
		end)
	end
end

function Clock.Start()
	RunService.Heartbeat:Connect(function(dt)
		acc1 += dt
		acc10 += dt
		if acc10 >= 0.1 then
			run(callbacks10, acc10 * Clock.timeScale)
			acc10 = 0
		end
		if acc1 >= 1 then
			run(callbacks1, acc1 * Clock.timeScale)
			acc1 = 0
		end
	end)
end

return Clock
