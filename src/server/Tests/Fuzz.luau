--!nonstrict
-- Fuzz semua remote C2S dengan argumen berbahaya. Syarat lulus:
--   1. tidak ada validator/handler yang melempar error (Net.handlerErrors tidak bertambah),
--   2. struktur data pemain yang stabil tidak berubah (argumen berbahaya tidak boleh mengubah state),
--   3. invarian bersih.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Fuzz")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Net = require(ReplicatedStorage.Shared.Net.Net)

local DataService = require(Server.Services.DataService)
local InvariantChecker = require(Server.Systems.InvariantChecker)

-- Remote yang sengaja dilewati: AdminCommand menerima string sah (perintah), ClientReady aman namun
-- mengirim ulang snapshot (tidak mengubah state).
local SKIP = { AdminCommand = true }

local HUGE_STRING = string.rep("x", 10000)

-- Satu entri = daftar argumen yang dibungkus table.pack (menjaga nil di tengah via field n).
local function P(...)
	return table.pack(...)
end

local function payloads(player)
	local list = {
		P(nil),
		P(0 / 0),
		P(math.huge),
		P(-math.huge),
		P(-1),
		P(1e308),
		P(2 ^ 53),
		P(""),
		P(HUGE_STRING),
		P("../../etc/passwd"),
		P("bad id!"),
		P({}),
		P({ { { {} } } }),
		P({ 1, 2, 3 }),
		P({ a = 1 }),
		P(Vector3.new(0 / 0, 1, 2)),
		P(Vector3.new(math.huge, 0, 0)),
		P(Vector3.new(1e30, 1e30, 1e30)),
		P(workspace),
		P(player),
		P(CFrame.new()),
		P("a1", {}),
		P({}, {}),
		P(1, 2),
		P("enum_x", HUGE_STRING),
		P(1, 2, 3),
		P(1, 2, 3, 4, 5),
		P(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
		P("dust_puff", "robux", "extra"),
		P(nil, nil, nil),
		P(nil, "a1"),
	}
	return list
end

-- Cuplikan stabil dari profil (tanpa nilai yang berubah sendiri seperti cash/progress/waktu).
local function stable(data)
	local out = {}
	local function add(label, value)
		table.insert(out, label .. "=" .. tostring(value))
	end
	local function addTable(label, t, fields)
		local keys = {}
		for k in t do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			local v = t[k]
			if type(v) == "table" then
				if fields then
					local parts = {}
					for _, f in fields do
						table.insert(parts, tostring(v[f]))
					end
					add(label .. "." .. tostring(k), table.concat(parts, "|"))
				else
					add(label .. "." .. tostring(k), "{table}")
				end
			else
				add(label .. "." .. tostring(k), v)
			end
		end
	end
	addTable("eggs", data.eggs, { "id", "kg", "loc", "growTotal" })
	addTable("pets", data.pets, { "id", "kg", "eq", "lock" })
	addTable("trails", data.trails.owned)
	add("trails.equipped", data.trails.equipped)
	addTable("found", data.index.found)
	addTable("claimed", data.index.claimed)
	for _, f in { "equipSlots", "penLevel", "wheelLevel", "plotExpansion", "trophies", "stardust" } do
		add(f, data[f])
	end
	add("hatched", data.stats.hatched)
	add("stolen", data.stats.stolen)
	add("tutorial", tostring(data.tutorial.step) .. tostring(data.tutorial.done))
	addTable("settings", data.settings)
	return table.concat(out, ";")
end

return function(T)
	if not T.userId then
		T.check("ada pemain", false, "jalankan Play dulu")
		return
	end
	local userId = T.userId
	local player = T.player

	DataService.wipe(userId)
	T.wait(1.5)
	local data = DataService.getByUserId(userId)
	data.tutorial.done = true -- supaya remote yang terkait tutorial/guardian ikut teruji

	local before = stable(DataService.getByUserId(userId))
	local errorsBefore = Net.handlerErrors
	local variants = payloads(player)

	local names = {}
	for name in Remotes.C2S do
		if not SKIP[name] then
			table.insert(names, name)
		end
	end
	table.sort(names)

	local calls = 0
	local function diff(a: string, b: string): string
		local setA, out = {}, {}
		for part in string.gmatch(a, "[^;]+") do
			setA[part] = true
		end
		for part in string.gmatch(b, "[^;]+") do
			if not setA[part] then
				table.insert(out, part)
			end
		end
		return table.concat(out, " , ")
	end

	for _, name in names do
		local pre = stable(DataService.getByUserId(userId))
		for _, payload in variants do
			local statuses = Net.inject(name, player, table.unpack(payload, 1, payload.n))
			calls += 1
			for _, status in statuses do
				if status == "error" or status == "validator_error" then
					T.check(`{name}: tidak melempar error`, false, status)
				end
			end
		end
		local post = stable(DataService.getByUserId(userId))
		if pre ~= post then
			T.check(`{name}: argumen berbahaya tidak mengubah state`, false, diff(pre, post))
		end
	end

	T.check(
		"tidak ada handler/validator yang melempar error",
		Net.handlerErrors == errorsBefore,
		Net.handlerErrors - errorsBefore
	)
	T.check("jumlah panggilan fuzz memadai", calls >= #names * #variants, calls)

	local after = stable(DataService.getByUserId(userId))
	T.check(
		"state stabil tidak berubah oleh argumen berbahaya",
		before == after,
		after ~= before and "state berubah" or nil
	)

	-- Remote tanpa argumen harus menolak argumen tambahan
	for _, name in
		{
			"DropEgg",
			"EquipBest",
			"ClaimIndexAll",
			"ClaimFreeBasket",
			"ActivateShield",
			"SwingPan",
			"ClaimCompanionStage",
		}
	do
		if Remotes.C2S[name] then
			local statuses = Net.inject(name, player, "extra")
			local rejected = true
			for _, st in statuses do
				if st ~= "invalid" then
					rejected = false
				end
			end
			T.check(`{name}: argumen tambahan ditolak`, rejected, table.concat(statuses, ","))
		end
	end

	T.check("data pemain tetap ada", DataService.getByUserId(userId) ~= nil)
	local inv = InvariantChecker.check()
	T.check("invarian bersih", #inv == 0, table.concat(inv, " | "))
end
