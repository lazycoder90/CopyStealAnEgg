--!nonstrict
-- Membangun dunia placeholder dari config (hub, 8 Coop, Hearth Line, lane 12 zona).
-- Semua dari bentuk dasar sehingga game bisa dimainkan tanpa aset. Dipanggil di Init (sinkron).
-- Sarang dan telur dibuat oleh EggSpawnService; guardian oleh GuardianService (Fase 2).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Zones = require(Shared.Config.Zones)
local NumberFormat = require(Shared.Logic.NumberFormat)
local Types = require(Shared.Types)

local Names, Attr, Tags = Types.Names, Types.Attr, Types.Tags

local MapBuilder = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function make(className: string, props: { [string]: any }, parent: Instance?): Instance
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
)
	return make("Part", {
		Name = name,
		Size = size,
		Position = pos,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
end

-- Lantai hub dan Coop: hijau limau berpola kotak (permukaan Studs hanya tampil pada material Plastic).
local FLOOR_COLOR = Color3.fromRGB(150, 225, 40)

local function studFloor(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	return part
end

local function sign(
	parent: BasePart,
	text: string,
	subtext: string?,
	color: Color3,
	studsHigh: number
)
	local gui = make("BillboardGui", {
		Name = "Sign",
		Size = UDim2.fromOffset(260, if subtext then 70 else 44),
		StudsOffset = Vector3.new(0, studsHigh, 0),
		AlwaysOnTop = false,
		MaxDistance = 200,
	}, parent)
	make("TextLabel", {
		Size = UDim2.fromScale(1, if subtext then 0.6 else 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeColor3 = Color3.fromRGB(60, 36, 20),
		TextStrokeTransparency = 0,
	}, gui)
	if subtext then
		make("TextLabel", {
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.4),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = subtext,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextStrokeColor3 = Color3.fromRGB(60, 36, 20),
			TextStrokeTransparency = 0.2,
		}, gui)
	end
end

local function buildHub(map: Folder)
	local width = Layout.hubHalfWidth * 2
	local depth = Layout.hubZMax - Layout.hubZMin
	local centerZ = (Layout.hubZMax + Layout.hubZMin) / 2
	local floor = block(
		map,
		"HubFloor",
		Vector3.new(width, 2, depth),
		-- Atas di y=-0.12 (bukan 0) agar tidak sebidang dengan lantai Coop (z-fighting/kedip).
		Vector3.new(0, -1.12, centerZ),
		FLOOR_COLOR
	)
	floor.Name = "HubFloor"
	studFloor(floor)

	-- Dinding hub (mencegah jatuh ke samping/belakang).
	local wallColor = Color3.fromRGB(86, 140, 70)
	local h = Layout.wallHeight
	block(
		map,
		"HubWallW",
		Vector3.new(2, h, depth),
		Vector3.new(-Layout.hubHalfWidth - 1, h / 2, centerZ),
		wallColor
	)
	block(
		map,
		"HubWallE",
		Vector3.new(2, h, depth),
		Vector3.new(Layout.hubHalfWidth + 1, h / 2, centerZ),
		wallColor
	)
	block(
		map,
		"HubWallS",
		Vector3.new(width, h, 2),
		Vector3.new(0, h / 2, Layout.hubZMin - 1),
		wallColor
	)

	-- Spawn pad (SpawnLocation netral di tengah hub).
	local pad = make("SpawnLocation", {
		Name = "SpawnPad",
		Size = Vector3.new(Layout.spawnPad.radius * 2, 1, Layout.spawnPad.radius * 2),
		Position = Vector3.new(Layout.spawnPad.x, 0.5, Layout.spawnPad.z),
		Color = Color3.fromRGB(255, 226, 150),
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		Neutral = true,
		Duration = 0,
		TopSurface = Enum.SurfaceType.Smooth,
	}, map)
	CollectionService:AddTag(pad, Tags.SpawnPad)

	-- Hearth Line: garis aman oranye berpendar melintang di batas hub/lane.
	local line = block(
		map,
		"HearthLine",
		Vector3.new(width, 0.4, 3),
		Vector3.new(0, 0.2, Layout.hearthLineZ),
		Color3.fromRGB(255, 150, 40),
		Enum.Material.Neon
	)
	line.CanCollide = false
	CollectionService:AddTag(line, Tags.HearthLine)

	-- Tulisan "SAFE ZONE" di lantai dekat Hearth Line.
	local label = block(
		map,
		"SafeZoneLabel",
		Vector3.new(120, 0.2, 22),
		Vector3.new(0, 0.1, Layout.hearthLineZ - 18),
		FLOOR_COLOR
	)
	label.CanCollide = false
	label.Transparency = 1
	local surface =
		make("SurfaceGui", { Face = Enum.NormalId.Top, CanvasSize = Vector2.new(600, 110) }, label)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = "SAFE ZONE",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.15,
		Rotation = 180,
	}, surface)

	-- Lentera di sepanjang Hearth Line.
	for x = -Layout.hubHalfWidth + 40, Layout.hubHalfWidth - 40, 80 do
		local post = block(
			map,
			"LanternPost",
			Vector3.new(1.2, 9, 1.2),
			Vector3.new(x, 4.5, Layout.hearthLineZ),
			Color3.fromRGB(110, 76, 44)
		)
		post.CanCollide = false
		local lamp = block(
			map,
			"LanternLamp",
			Vector3.new(2.4, 2.4, 2.4),
			Vector3.new(x, 9.8, Layout.hearthLineZ),
			Color3.fromRGB(255, 214, 120),
			Enum.Material.Neon
		)
		lamp.CanCollide = false
		make(
			"PointLight",
			{ Color = Color3.fromRGB(255, 200, 120), Range = 22, Brightness = 1.2 },
			lamp
		)
	end
end

local function buildPlots()
	local plots = make("Folder", { Name = Names.Plots }, workspace)
	local size = Layout.plotSize
	local fenceColor = Color3.fromRGB(150, 104, 62)
	local gate = Layout.plotGateWidth

	for i = 1, Layout.plotCount do
		local cx, cz = Layout.plotCenter(i)
		local model = make("Model", { Name = `Plot_{i}` }, plots)
		model:SetAttribute(Attr.OwnerUserId, 0)
		model:SetAttribute(Attr.PlotIndex, i)
		CollectionService:AddTag(model, Tags.Coop)

		local floor = block(
			model,
			Names.PlotFloor,
			Vector3.new(size, 1, size),
			Vector3.new(cx, -0.5, cz),
			FLOOR_COLOR
		)
		studFloor(floor)
		model.PrimaryPart = floor

		-- Pagar: 3 sisi penuh, sisi lane (+Z) punya celah gerbang di tengah.
		local half = size / 2
		local fenceH = 4
		block(
			model,
			"FenceS",
			Vector3.new(size, fenceH, 1),
			Vector3.new(cx, fenceH / 2, cz - half),
			fenceColor
		)
		block(
			model,
			"FenceW",
			Vector3.new(1, fenceH, size - 1),
			Vector3.new(cx - half, fenceH / 2, cz + 0.5),
			fenceColor
		)
		block(
			model,
			"FenceE",
			Vector3.new(1, fenceH, size - 1),
			Vector3.new(cx + half, fenceH / 2, cz + 0.5),
			fenceColor
		)
		local seg = (size - gate) / 2
		block(
			model,
			"FenceNW",
			Vector3.new(seg, fenceH, 1),
			Vector3.new(cx - half + seg / 2, fenceH / 2, cz + half),
			fenceColor
		)
		block(
			model,
			"FenceNE",
			Vector3.new(seg, fenceH, 1),
			Vector3.new(cx + half - seg / 2, fenceH / 2, cz + half),
			fenceColor
		)

		make("Part", {
			Name = Names.PlotSpawn,
			Size = Vector3.new(4, 1, 4),
			Position = Vector3.new(cx + Layout.plotSpawnLocal.x, 0.5, cz + Layout.plotSpawnLocal.z),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Transparency = 1,
		}, model)

		local signPart = block(
			model,
			"SignAnchor",
			Vector3.new(1, 1, 1),
			Vector3.new(cx, 8, cz + half),
			Color3.fromRGB(255, 255, 255)
		)
		signPart.Transparency = 1
		signPart.CanCollide = false
		sign(signPart, `Coop {i}`, "Free - claim by joining", Color3.fromRGB(255, 226, 120), 0)

		make("Folder", { Name = Names.PlotEggs }, model)
		make("Folder", { Name = Names.PlotPets }, model)
	end
end

local function buildLane(map: Folder)
	local laneFolder = make("Folder", { Name = "Lane" }, map)
	local half = Layout.laneWidth / 2
	local h = Layout.wallHeight

	for _, zone in Zones.list do
		local zStart = Layout.zoneZStart(zone.index)
		local zEnd = Layout.zoneZEnd(zone.index)
		local centerZ = (zStart + zEnd) / 2
		local folder = make("Folder", { Name = `Zone_{zone.index}_{zone.id}` }, laneFolder)
		folder:SetAttribute(Attr.ZoneIndex, zone.index)

		local floorColor = rgb(zone.floorRgb)
		local wallColor = rgb(zone.wallRgb)
		block(
			folder,
			"Floor",
			Vector3.new(Layout.laneWidth, 2, Layout.zoneLength),
			Vector3.new(0, -1, centerZ),
			floorColor,
			Enum.Material.Grass
		)
		block(
			folder,
			"WallW",
			Vector3.new(2, h, Layout.zoneLength),
			Vector3.new(-half - 1, h / 2, centerZ),
			wallColor
		)
		block(
			folder,
			"WallE",
			Vector3.new(2, h, Layout.zoneLength),
			Vector3.new(half + 1, h / 2, centerZ),
			wallColor
		)

		-- Gerbang zona: dua tiang + balok atas + papan nama.
		local accent = rgb(zone.accentRgb)
		block(
			folder,
			"GatePostW",
			Vector3.new(3, 18, 3),
			Vector3.new(-half + 2, 9, zStart + 2),
			accent
		)
		block(
			folder,
			"GatePostE",
			Vector3.new(3, 18, 3),
			Vector3.new(half - 2, 9, zStart + 2),
			accent
		)
		local beam = block(
			folder,
			"GateBeam",
			Vector3.new(Layout.laneWidth - 4, 3, 3),
			Vector3.new(0, 19, zStart + 2),
			accent
		)
		local subtext = if zone.recSpeed > 0
			then `Recommended speed: {NumberFormat.fmt(zone.recSpeed)}`
			else "Starter zone"
		sign(beam, zone.name, subtext, Color3.fromRGB(255, 255, 255), 4)
	end

	-- Penutup ujung lane.
	local endZ = Layout.zoneZEnd(Zones.count)
	block(
		laneFolder,
		"LaneEnd",
		Vector3.new(Layout.laneWidth + 4, h, 2),
		Vector3.new(0, h / 2, endZ + 1),
		Color3.fromRGB(24, 20, 36)
	)
end

function MapBuilder.Init()
	-- Singkirkan template bawaan Studio agar tidak bertabrakan dengan peta kita.
	for _, name in { "Baseplate", "SpawnLocation", Names.Map, Names.Plots } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local map = make("Folder", { Name = Names.Map }, workspace)
	buildHub(map)
	buildPlots()
	buildLane(map)
	make("Folder", { Name = Names.WorldEggs }, workspace)
	make("Folder", { Name = Names.Guardians }, workspace)
	make("Folder", { Name = Names.Effects }, workspace)

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
end

return MapBuilder
