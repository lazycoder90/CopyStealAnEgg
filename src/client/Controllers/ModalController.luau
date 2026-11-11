--!nonstrict
-- Satu modal pada satu waktu. Panel lain mendaftar lewat register(name, builder).
-- builder(container) mengisi frame konten dan boleh mengembalikan fungsi pembersih.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent.UI
local Modal = require(UI.Components.Modal)
local UIBuilder = require(UI.UIBuilder)

local ModalController = {}

local registry = {} -- name -> { builder, title }
local gui
local current -- { name, modal, cleanup }

function ModalController.register(name: string, builder: (Frame) -> (() -> ())?, title: string?)
	registry[name] = { builder = builder, title = title or name }
end

function ModalController.isOpen(): boolean
	return current ~= nil
end

function ModalController.close()
	local open = current
	if not open then
		return
	end
	current = nil
	if open.cleanup then
		local ok, err = pcall(open.cleanup)
		if not ok then
			warn("[ModalController] cleanup gagal:", err)
		end
	end
	if open.modal.backdrop then
		open.modal.backdrop:Destroy()
	end
end

ModalController.closeAll = ModalController.close

function ModalController.open(name: string)
	local entry = registry[name]
	if not entry or not gui then
		warn("[ModalController] modal tidak terdaftar: " .. tostring(name))
		return
	end
	ModalController.close()
	local modal = Modal.new(gui, entry.title, ModalController.close)
	local open = { name = name, modal = modal }
	current = open
	local ok, result = pcall(entry.builder, modal.content)
	if not ok then
		warn("[ModalController] builder gagal:", result)
		if current == open then
			ModalController.close()
		end
		return
	end
	if type(result) == "function" then
		open.cleanup = result
	end
end

function ModalController.getCurrentName(): string?
	return current and current.name
end

function ModalController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "Modals",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		IgnoreGuiInset = true,
	})
	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and current then
			ModalController.close()
		end
	end)
end

return ModalController
