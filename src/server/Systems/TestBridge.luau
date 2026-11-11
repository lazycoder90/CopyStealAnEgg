--!nonstrict
-- Jembatan uji (HANYA Studio). Membuat ServerStorage.TestBridge (BindableFunction) yang menjalankan
-- fungsi di dalam konteks server SUNGGUHAN (bukan salinan modul seperti execute_luau).
--
-- Dipanggil dari MCP (execute_luau, Server):
--   game.ServerStorage.TestBridge:Invoke("test.run", "Boot")  -> { ok, result | error }
--
-- Service mendaftarkan hook sendiri: TestBridge.register("nama.hook", function(...) return nilai end)
-- Skenario uji berada di src/server/Tests/<Nama>.luau, bentuk: return function(T) ... end
--   T.player, T.userId, T.check(nama, kondisi, detail?), T.wait(detik)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local TestBridge = {}

local handlers = {}

function TestBridge.register(name: string, fn: (...any) -> any)
	handlers[name] = fn
end

function TestBridge.getPlayer(): Player?
	return Players:GetPlayers()[1]
end

-- Serialisasi deterministik untuk hash state.
local function serialize(value, out)
	if type(value) == "table" then
		local keys = {}
		for k in value do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		table.insert(out, "{")
		for _, k in keys do
			table.insert(out, tostring(k) .. "=")
			serialize(value[k], out)
			table.insert(out, ",")
		end
		table.insert(out, "}")
	else
		table.insert(out, tostring(value))
	end
end

-- Kunci yang berubah sendiri (waktu) tidak ikut hash supaya perbandingan state stabil.
local HASH_IGNORED = { lastOnline = true }

local function stripIgnored(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		if not HASH_IGNORED[k] then
			out[k] = stripIgnored(v)
		end
	end
	return out
end

local function hash(value): (number, number)
	local out = {}
	serialize(stripIgnored(value), out)
	local s = table.concat(out)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return h, #s
end

local function getPath(root, path: string)
	local node = root
	for _, key in string.split(path, ".") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

local function runTests(testsFolder: Instance, only: string?)
	local results = {}
	local player = TestBridge.getPlayer()
	local function T_new(suite: string)
		return {
			player = player,
			userId = player and player.UserId,
			wait = task.wait,
			check = function(name: string, condition: any, detail: any?)
				table.insert(results, {
					suite = suite,
					name = name,
					pass = condition == true or (condition ~= false and condition ~= nil),
					detail = if detail ~= nil then tostring(detail) else nil,
				})
			end,
		}
	end

	local modules = {}
	for _, child in testsFolder:GetChildren() do
		if child:IsA("ModuleScript") and (only == nil or child.Name == only) then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)

	for _, module in modules do
		local T = T_new(module.Name)
		local ok, err = xpcall(function()
			require(module)(T)
		end, debug.traceback)
		if not ok then
			table.insert(
				results,
				{ suite = module.Name, name = "(suite error)", pass = false, detail = err }
			)
		end
	end

	local passed, failed = 0, 0
	local failures = {}
	for _, r in results do
		if r.pass then
			passed += 1
		else
			failed += 1
			table.insert(
				failures,
				`{r.suite}: {r.name}{if r.detail then " -> " .. r.detail else ""}`
			)
		end
	end
	return {
		passed = passed,
		failed = failed,
		total = #results,
		failures = failures,
		suites = #modules,
	}
end

function TestBridge.Init()
	if not RunService:IsStudio() then
		return
	end

	local Server = script.Parent.Parent
	local Boot = require(Server.Boot)
	local DataService = require(Server.Services.DataService)
	local InvariantChecker = require(script.Parent.InvariantChecker)
	local testsFolder = Server:FindFirstChild("Tests")

	TestBridge.register("ping", function()
		return "pong"
	end)
	TestBridge.register("boot.report", function()
		return Boot.report()
	end)
	TestBridge.register("player", function()
		local p = TestBridge.getPlayer()
		return p and { userId = p.UserId, name = p.Name } or nil
	end)
	TestBridge.register("state.get", function(userId, path)
		local data = DataService.getByUserId(userId)
		if not data then
			return nil
		end
		return if path then getPath(data, path) else data
	end)
	TestBridge.register("state.hash", function(userId)
		local data = DataService.getByUserId(userId)
		if not data then
			return nil
		end
		local h, len = hash(data)
		return { hash = h, length = len }
	end)
	TestBridge.register("lifecycle.simulateRejoin", function(userId)
		return DataService.simulateRejoin(userId)
	end)
	TestBridge.register("invariants.check", function()
		return InvariantChecker.check()
	end)
	TestBridge.register("test.list", function()
		local names = {}
		if testsFolder then
			for _, child in testsFolder:GetChildren() do
				table.insert(names, child.Name)
			end
			table.sort(names)
		end
		return names
	end)
	TestBridge.register("test.run", function(only)
		if not testsFolder then
			return { passed = 0, failed = 0, total = 0, failures = {}, suites = 0 }
		end
		return runTests(testsFolder, only)
	end)

	local bridge = Instance.new("BindableFunction")
	bridge.Name = Types.Names.TestBridge
	bridge.OnInvoke = function(name, ...)
		local fn = handlers[name]
		if not fn then
			return { ok = false, error = "hook tidak dikenal: " .. tostring(name) }
		end
		local ok, result = pcall(fn, ...)
		if ok then
			return { ok = true, result = result }
		end
		return { ok = false, error = tostring(result) }
	end
	bridge.Parent = ServerStorage
end

return TestBridge
