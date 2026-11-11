--!nonstrict
-- Pembungkus remote.
-- Server : Net.on(name, validator, handler), Net.fire, Net.fireAll
-- Klien  : Net.connect(name, handler), Net.send(name, ...)
-- Net.on WAJIB memakai validator (lihat Util/Check.luau). Handler dibungkus pcall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)
local RateLimiter = require(script.Parent.Parent.Logic.RateLimiter)
local Types = require(script.Parent.Parent.Types)

local Net = {}
local folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = Types.Names.Remotes

	for name in Remotes.C2S do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	for _, name in Remotes.S2C do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	for _, name in Remotes.Functions do
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage

	local limiters = {}
	Net.handled = {} -- nama remote C2S yang sudah punya handler (untuk pemeriksaan boot)

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:clear(player.UserId)
		end
	end)

	function Net.on(name: string, validator: (...any) -> boolean, handler: (Player, ...any) -> ())
		assert(type(validator) == "function", "Net.on('" .. name .. "') butuh validator")
		local remote = folder:FindFirstChild(name)
		assert(remote and remote:IsA("RemoteEvent"), "Remote tidak dikenal: " .. name)
		assert(Remotes.C2S[name], "Net.on hanya untuk remote C2S: " .. name)
		local limiter = RateLimiter.new(Remotes.C2S[name], os.clock)
		table.insert(limiters, limiter)
		Net.handled[name] = true
		remote.OnServerEvent:Connect(function(player, ...)
			if not limiter:allow(player.UserId) then
				return
			end
			if not validator(...) then
				return
			end
			local ok, err = pcall(handler, player, ...)
			if not ok then
				warn(`[Net] handler {name} gagal: {err}`)
			end
		end)
	end

	function Net.fire(name: string, player: Player, ...)
		folder[name]:FireClient(player, ...)
	end

	function Net.fireAll(name: string, ...)
		folder[name]:FireAllClients(...)
	end
else
	folder = ReplicatedStorage:WaitForChild(Types.Names.Remotes)

	function Net.connect(name: string, handler: (...any) -> ())
		return folder:WaitForChild(name).OnClientEvent:Connect(handler)
	end

	function Net.send(name: string, ...)
		folder:WaitForChild(name):FireServer(...)
	end
end

return Net
