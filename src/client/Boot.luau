--!nonstrict
-- Pemuat otomatis klien: require semua ModuleScript di folder, lalu Init dan Start SINKRON
-- (Start tidak boleh yield sebelum menyambung listener remote). Setelah itu pemanggil
-- mengirim ClientReady supaya server mengirim snapshot state.

local Boot = { failed = {}, loaded = {} }

local function fail(stage: string, name: string, err)
	table.insert(Boot.failed, { stage = stage, name = name, error = tostring(err) })
	task.spawn(error, `[Boot/Client] {name} gagal di {stage}: {err}`, 0)
end

function Boot.run(folders: { Instance })
	local mods = {}
	for _, folder in folders do
		local children = folder:GetChildren()
		table.sort(children, function(a, b)
			return a.Name < b.Name
		end)
		for _, child in children do
			if child:IsA("ModuleScript") then
				local ok, result = xpcall(require, debug.traceback, child)
				if ok then
					table.insert(mods, { name = child.Name, mod = result })
					table.insert(Boot.loaded, child.Name)
				else
					fail("require", child.Name, result)
				end
			end
		end
	end

	for _, phase in { "Init", "Start" } do
		for _, item in mods do
			local fn = type(item.mod) == "table" and item.mod[phase]
			if type(fn) == "function" then
				local ok, err = xpcall(fn, debug.traceback, item.mod)
				if not ok then
					fail(phase, item.name, err)
				end
			end
		end
	end
end

return Boot
