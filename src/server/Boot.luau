--!nonstrict
-- Pemuat otomatis: require semua ModuleScript di folder yang diberikan, lalu menjalankan
--   fase Init (sinkron, tanpa yield, tanpa memanggil service lain),
--   fase Start (loop/koneksi; boleh yield, dijalankan lewat task.spawn),
--   fase Ready (setelah semua Start; dipakai DataService agar pemain baru diproses terakhir).
-- Kegagalan satu modul tidak mematikan modul lain, tetapi dicatat merah dan masuk Boot.report().

local Boot = { failed = {}, loaded = {} }

local function fail(stage: string, name: string, err)
	local message = `[Boot] {name} gagal di {stage}: {err}`
	table.insert(Boot.failed, { stage = stage, name = name, error = tostring(err) })
	task.spawn(error, message, 0) -- tampil sebagai error merah di Output
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

	for _, phase in { "Init", "Start", "Ready" } do
		for _, item in mods do
			local fn = type(item.mod) == "table" and item.mod[phase]
			if type(fn) == "function" then
				if phase == "Init" then
					local ok, err = xpcall(fn, debug.traceback, item.mod)
					if not ok then
						fail(phase, item.name, err)
					end
				else
					task.spawn(function()
						local ok, err = xpcall(fn, debug.traceback, item.mod)
						if not ok then
							fail(phase, item.name, err)
						end
					end)
				end
			end
		end
	end
end

function Boot.report()
	return { loaded = Boot.loaded, failed = Boot.failed }
end

return Boot
