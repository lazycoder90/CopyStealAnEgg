--!nonstrict
-- Feed pengumuman di bawah area banner zona: maks 3 baris, terbaru di atas, pudar setelah 6 detik.
-- Tiap baris = daftar TextLabel berwarna dari segmen. Juga mencoba menulis ke chat sistem (RichText, dibungkus pcall).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventsConfig = require(Shared.Config.EventsConfig)
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)

local AnnouncementController = {}

local feed = EventsConfig.feed
local FADE = 0.5

local gui, list
local rows = {} -- terlama di indeks 1
local order = 0

local function toColor(rgb): Color3
	if type(rgb) ~= "table" then
		return Theme.Colors.White
	end
	return Color3.fromRGB(
		math.clamp(rgb[1] or 255, 0, 255),
		math.clamp(rgb[2] or 255, 0, 255),
		math.clamp(rgb[3] or 255, 0, 255)
	)
end

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- Chat sistem (opsional): gagal diam-diam bila TextChatService tidak tersedia.
local function chatSystem(segments)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = channels and channels:FindFirstChild("RBXSystem")
		if not system then
			return
		end
		local parts = {}
		for _, seg in segments do
			local c = toColor(seg.color)
			table.insert(
				parts,
				string.format(
					'<font color="#%02X%02X%02X">%s</font>',
					math.floor(c.R * 255 + 0.5),
					math.floor(c.G * 255 + 0.5),
					math.floor(c.B * 255 + 0.5),
					escape(seg.text)
				)
			)
		end
		system:DisplaySystemMessage(table.concat(parts))
	end)
end

local function removeRow(row)
	local idx = table.find(rows, row)
	if idx then
		table.remove(rows, idx)
	end
	if row.Parent then
		TweenService:Create(row, TweenInfo.new(FADE), { GroupTransparency = 1 }):Play()
		task.delay(FADE, function()
			row:Destroy()
		end)
	end
end

local function addRow(segments)
	order -= 1 -- LayoutOrder menurun: terbaru di atas
	local row = UIBuilder.create("CanvasGroup", {
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UIBuilder.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	for i, seg in segments do
		UIBuilder.create("TextLabel", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextSize = 20,
			TextColor3 = toColor(seg.color),
			Text = tostring(seg.text),
			Parent = row,
			[UIBuilder.Children] = {
				UIBuilder.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Brown }),
			},
		})
	end
	row.Parent = list
	table.insert(rows, row)
	while #rows > feed.maxRows do
		removeRow(rows[1])
	end
	task.delay(feed.lifetime, function()
		if table.find(rows, row) then
			removeRow(row)
		end
	end)
end

local function onAnnounce(payload)
	if type(payload) ~= "table" or type(payload.segments) ~= "table" then
		return
	end
	local segments = {}
	for _, seg in payload.segments do
		if type(seg) == "table" and type(seg.text) == "string" then
			table.insert(segments, seg)
		end
	end
	if #segments == 0 then
		return
	end
	if list then
		addRow(segments)
	end
	chatSystem(segments)
end

function AnnouncementController.Start()
	gui = UIBuilder.create("ScreenGui", {
		Name = "AnnouncementFeed",
		ResetOnSpawn = false,
		DisplayOrder = 16,
	})
	list = UIBuilder.create("Frame", {
		Name = "List",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, feed.topOffset),
		Size = UDim2.fromOffset(600, 3 * 34),
		BackgroundTransparency = 1,
		Parent = gui,
		[UIBuilder.Children] = {
			UIBuilder.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
		},
	})
	UIBuilder.create("UISizeConstraint", { MaxSize = Vector2.new(600, 120), Parent = list })

	Net.connect("Announce", onAnnounce)

	task.spawn(function()
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end

return AnnouncementController
