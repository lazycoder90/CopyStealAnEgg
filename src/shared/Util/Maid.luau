--!nonstrict
-- Pembersih sumber daya (koneksi, Instance, fungsi). Dipakai per pemain/per objek.

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

-- Mengembalikan task agar bisa dipakai berantai: local c = maid:Give(signal:Connect(...))
function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

local function clean(task)
	local kind = typeof(task)
	if kind == "function" then
		task()
	elseif kind == "RBXScriptConnection" then
		task:Disconnect()
	elseif kind == "Instance" then
		task:Destroy()
	elseif kind == "table" then
		if type(task.Disconnect) == "function" then
			task:Disconnect()
		elseif type(task.Destroy) == "function" then
			task:Destroy()
		elseif type(task.Clean) == "function" then
			task:Clean()
		end
	end
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local ok, err = pcall(clean, tasks[i])
		if not ok then
			warn("[Maid] gagal membersihkan:", err)
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
