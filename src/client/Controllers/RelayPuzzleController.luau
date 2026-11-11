--!nonstrict
-- Modal "Realign the Star Relay". Puzzle datang dari server lewat S2C StarwhaleState (payload.puzzle,
-- tanpa solusi) setelah pemain menekan prompt Tilly. TillyController yang membuka modal ini.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarwhaleConfig = require(Shared.Config.StarwhaleConfig)
local Net = require(Shared.Net.Net)
local Signal = require(Shared.Util.Signal)

local UI = script.Parent.Parent.UI
local RelayPuzzle = require(UI.Screens.RelayPuzzle)
local ModalController = require(script.Parent.ModalController)
local StateController = require(script.Parent.StateController)

local RelayPuzzleController = {}
RelayPuzzleController.puzzle = nil
RelayPuzzleController.changed = Signal.new()

-- Hapus puzzle lama sebelum membuka modal (puzzle baru dibuat server per permintaan).
function RelayPuzzleController.clear()
	RelayPuzzleController.puzzle = nil
end

function RelayPuzzleController.Start()
	ModalController.register(StarwhaleConfig.modalRelay, function(container)
		return RelayPuzzle.build(container, RelayPuzzleController)
	end, "Realign the Star Relay")

	Net.connect("StarwhaleState", function(payload)
		if type(payload) == "table" and payload.puzzle then
			RelayPuzzleController.puzzle = payload.puzzle
			RelayPuzzleController.changed:Fire()
		end
	end)

	-- Relay diperbaiki: tutup modal puzzle.
	StateController.changed:Connect(function(path, value)
		if
			path == "starwhale.relayFixed"
			and value == true
			and ModalController.getCurrentName() == StarwhaleConfig.modalRelay
		then
			RelayPuzzleController.puzzle = nil
			ModalController.close()
		end
	end)
end

return RelayPuzzleController
