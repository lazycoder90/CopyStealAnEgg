--!nonstrict
-- Isi modal "Realign the Star Relay": grid 5x5 ubin (I, L, T, X digambar dengan batang neon tebal).
-- Klik ubin = putar 90 derajat (tween). Tombol Reset dan Submit. Penanda IN di kiri source, OUT di
-- kanan target. ctl = RelayPuzzleController ({ puzzle, changed }). Mengembalikan fungsi pembersih.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local UIBuilder = require(UI.UIBuilder)
local Button = require(UI.Components.Button)

local RelayPuzzle = {}

local TILE_BG = Color3.fromRGB(34, 42, 82)
local BAR = Color3.fromRGB(110, 230, 255)
local BAR_W = 0.3 -- tebal batang (fraksi tile)
local ROTATE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Bukaan dasar (rot 0): 1=N, 2=E, 3=S, 4=W (sama dengan Logic/PipePuzzle).
local BASE = {
	I = { 1, 3 },
	L = { 1, 2 },
	T = { 1, 2, 3 },
	X = { 1, 2, 3, 4 },
}

-- Properti Frame batang dari pusat ubin ke tepi pada arah d.
local ARMS = {
	[1] = { anchor = Vector2.new(0.5, 1), size = UDim2.fromScale(BAR_W, 0.5) },
	[2] = { anchor = Vector2.new(0, 0.5), size = UDim2.fromScale(0.5, BAR_W) },
	[3] = { anchor = Vector2.new(0.5, 0), size = UDim2.fromScale(BAR_W, 0.5) },
	[4] = { anchor = Vector2.new(1, 0.5), size = UDim2.fromScale(0.5, BAR_W) },
}

local function bar(parent: Instance, props)
	props.BackgroundColor3 = BAR
	props.BorderSizePixel = 0
	props.ZIndex = 5
	props.Parent = parent
	return UIBuilder.create("Frame", props)
end

local function buildTile(parent: Instance, kind: string, order: number)
	local button = UIBuilder.create("TextButton", {
		Name = "Tile",
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		BackgroundColor3 = TILE_BG,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIBuilder.create("UIStroke", { Thickness = 1.5, Color = Theme.Colors.Brown }),
		},
	})
	local rotor = UIBuilder.create("Frame", {
		Name = "Rotor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = button,
	})
	bar(rotor, {
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(BAR_W, BAR_W),
	})
	for _, d in BASE[kind] or {} do
		local arm = ARMS[d]
		bar(rotor, {
			Name = "Arm" .. d,
			AnchorPoint = arm.anchor,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = arm.size,
		})
	end
	return button, rotor
end

local function marker(parent: Instance, text: string, row: number, onLeft: boolean)
	local rowCenter = ((row - 1) * 0.2025 + 0.095)
	return UIBuilder.create("TextLabel", {
		Name = if onLeft then "SourceMarker" else "TargetMarker",
		AnchorPoint = Vector2.new(if onLeft then 1 else 0, 0.5),
		Position = UDim2.new(if onLeft then 0 else 1, if onLeft then -4 else 4, rowCenter, 0),
		Size = UDim2.fromOffset(52, 24),
		BackgroundColor3 = Theme.Colors.Yolk,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = Theme.Colors.Brown,
		Text = text,
		ZIndex = 6,
		Parent = parent,
		[UIBuilder.Children] = {
			UIBuilder.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		},
	})
end

function RelayPuzzle.build(container: Frame, ctl)
	local title = UIBuilder.create("TextLabel", {
		Name = "Instruction",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = "ROTATE TILES TO CONNECT THE POWER",
		ZIndex = 4,
		Parent = container,
	})
	local status = UIBuilder.create("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 30),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextSize = 18,
		TextColor3 = Theme.Colors.Brown,
		Text = "Calibrating the relay...",
		ZIndex = 4,
		Parent = container,
	})
	local holder = UIBuilder.create("Frame", {
		Name = "GridHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Visible = false,
		Parent = container,
	})
	local reset, submit

	local rots, initial, turns, rotors = {}, {}, {}, {}
	local alive = true

	local function fit()
		local abs = container.AbsoluteSize
		local side = math.max(120, math.min(abs.X - 130, abs.Y - 30 - 52))
		holder.Size = UDim2.fromOffset(side, side)
	end
	fit()
	local sizeConn = container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local function rotateTo(r: number, c: number, newTurns: number)
		turns[r][c] = newTurns
		TweenService:Create(rotors[r][c], ROTATE, { Rotation = newTurns * 90 }):Play()
	end

	local function render()
		for _, child in holder:GetChildren() do
			child:Destroy()
		end
		local puzzle = ctl.puzzle
		holder.Visible = puzzle ~= nil
		status.Visible = puzzle == nil
		if reset then
			reset.Visible = puzzle ~= nil
			submit.Visible = puzzle ~= nil
		end
		if not puzzle then
			return
		end
		local n = puzzle.size
		UIBuilder.create("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = UDim2.fromScale(0.19, 0.19),
			CellPadding = UDim2.fromScale(0.0125, 0.0125),
			Parent = holder,
		})
		rots, initial, turns, rotors = {}, {}, {}, {}
		for r = 1, n do
			rots[r], initial[r], turns[r], rotors[r] = {}, {}, {}, {}
			for c = 1, n do
				local tile = puzzle.tiles[r][c]
				local button, rotor = buildTile(holder, tile.kind, (r - 1) * n + c)
				rotor.Rotation = tile.rot * 90
				rots[r][c], initial[r][c], turns[r][c], rotors[r][c] =
					tile.rot, tile.rot, tile.rot, rotor
				button.Activated:Connect(function()
					rots[r][c] = (rots[r][c] + 1) % 4
					rotateTo(r, c, turns[r][c] + 1)
				end)
			end
		end
		marker(holder, "IN >", puzzle.source.row, true)
		marker(holder, "> OUT", puzzle.target.row, false)
	end

	reset = Button.new({
		name = "Reset",
		text = "Reset",
		color = Theme.Colors.Brick,
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(0.5, -8, 1, 0),
		size = UDim2.fromOffset(130, 42),
		textSize = 20,
		parent = container,
		onClick = function()
			if not ctl.puzzle then
				return
			end
			for r = 1, ctl.puzzle.size do
				for c = 1, ctl.puzzle.size do
					rots[r][c] = initial[r][c]
					rotateTo(r, c, turns[r][c] + (initial[r][c] - turns[r][c]) % 4)
				end
			end
		end,
	})
	submit = Button.new({
		name = "Submit",
		text = "Submit",
		color = Theme.Colors.Mint,
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.new(0.5, 8, 1, 0),
		size = UDim2.fromOffset(130, 42),
		textSize = 20,
		parent = container,
		onClick = function()
			if not (ctl.puzzle and alive) then
				return
			end
			local out = {}
			for r = 1, ctl.puzzle.size do
				out[r] = {}
				for c = 1, ctl.puzzle.size do
					out[r][c] = rots[r][c]
				end
			end
			Net.send("SubmitRelay", out)
		end,
	})
	reset.ZIndex = 5
	submit.ZIndex = 5

	local connection = ctl.changed:Connect(render)
	render()
	title.ZIndex = 4

	return function()
		alive = false
		connection:Disconnect()
		sizeConn:Disconnect()
	end
end

return RelayPuzzle
