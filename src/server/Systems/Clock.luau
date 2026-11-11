--!nonstrict
-- Clock terpusat: satu loop Heartbeat untuk semua tick 1 Hz dan 10 Hz.
-- Callback menerima dt dalam "waktu game" (sudah dikali timeScale, untuk /timescale admin).

local RunService = game:GetService("RunService")

local Clock = { timeScale = 1 }

local callbacks1, callbacks10 = {}, {}
local acc1, acc10 = 0, 0

function Clock.every1Hz(fn: (dt: number) -> ())
	table.insert(callbacks1, fn)
end

function Clock.every10Hz(fn: (dt: number) -> ())
	table.insert(callbacks10, fn)
end

local function run(list, dt)
	for _, fn in list do
		task.spawn(fn, dt)
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
