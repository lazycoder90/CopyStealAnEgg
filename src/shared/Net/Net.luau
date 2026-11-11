--!nonstrict
-- Pembungkus remote. Server: membuat remote, Net.on (dengan rate limit), Net.fire.
-- Klien: Net.connect, Net.send.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)
local RateLimiter = require(script.Parent.Parent.Logic.RateLimiter)

local Net = {}
local folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"

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
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:clear(player.UserId)
		end
	end)

	-- handler(player, ...) dipanggil hanya jika lolos rate limit.
	function Net.on(name: string, handler: (Player, ...any) -> ())
		local remote = folder:FindFirstChild(name)
		assert(remote and remote:IsA("RemoteEvent"), "Remote tidak dikenal: " .. name)
		local rate = Remotes.C2S[name] or 10
		local limiter = RateLimiter.new(rate, os.clock)
		table.insert(limiters, limiter)
		remote.OnServerEvent:Connect(function(player, ...)
			if limiter:allow(player.UserId) then
				handler(player, ...)
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
	folder = ReplicatedStorage:WaitForChild("Remotes")

	function Net.connect(name: string, handler: (...any) -> ())
		return folder:WaitForChild(name).OnClientEvent:Connect(handler)
	end

	function Net.send(name: string, ...)
		folder:WaitForChild(name):FireServer(...)
	end
end

return Net
