--!nonstrict
-- Menyimpan replika data pemain dari server (StateInit + StatePatch) dan memberi tahu perubahan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Signal = require(Shared.Util.Signal)

local StateController = {}
StateController.state = {}
StateController.changed = Signal.new() -- (path, value)
StateController.ready = Signal.new()
StateController.isReady = false

local function setPath(path: string, value)
	local keys = string.split(path, ".")
	local node = StateController.state
	for i = 1, #keys - 1 do
		local nxt = node[keys[i]]
		if type(nxt) ~= "table" then
			nxt = {}
			node[keys[i]] = nxt
		end
		node = nxt
	end
	node[keys[#keys]] = value
end

function StateController.get(path: string)
	local node = StateController.state
	for _, key in string.split(path, ".") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

function StateController.Start()
	Net.connect("StateInit", function(snapshot)
		StateController.state = snapshot
		StateController.isReady = true
		StateController.ready:Fire()
		StateController.changed:Fire("*", snapshot)
	end)

	Net.connect("StatePatch", function(patches)
		for _, patch in patches do
			setPath(patch[1], patch[2])
			StateController.changed:Fire(patch[1], patch[2])
		end
	end)
end

return StateController
