--!nonstrict
-- Model placeholder Nestwarden dari primitif (tema per zona). Tanpa API server.
-- PrimaryPart "Body", semua Anchored, tanpa tabrakan (guardian tidak memblokir pemain).
-- Status: BillboardGui "Status" berisi label "Zzz" (Sleep) dan "!" (Alert); diatur lewat setState.

local Types = require(script.Parent.Types)

local GuardianModels = {}

local STATUS_NAME = "Status"
local ZZZ_NAME = "Zzz"
local ALERT_NAME = "Alert"

-- Bentuk khas per guardian (id dari Config/Zones).
local THEMES = {
	grumblemoss = { feature = "shell" },
	old_croakbeard = { feature = "bulge" },
	vinemaw = { feature = "vines" },
	sandcrank = { feature = "shell" },
	brrumble = { feature = "horns" },
	magmole = { feature = "claws" },
	tidejaw = { feature = "claws" },
	ossidon = { feature = "spikes" },
	paperwing = { feature = "wings" },
	nebulynx = { feature = "horns" },
	gearhulk = { feature = "gears" },
	umbrageist = { feature = "eyes" },
}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3
)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.Parent = model
	return p
end

local function makeLabel(name: string, text: string, color: Color3, visible: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Visible = visible
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(86, 52, 28)
	stroke.Parent = label
	return label
end

-- Menampilkan label sesuai state (dipanggil SERVER saat state berubah; ikut replikasi).
function GuardianModels.setState(model: Model, state: string)
	model:SetAttribute(Types.Attr.GuardianState, state)
	local body = model.PrimaryPart
	local gui = body and body:FindFirstChild(STATUS_NAME)
	if not gui then
		return
	end
	local zzz = gui:FindFirstChild(ZZZ_NAME)
	local alert = gui:FindFirstChild(ALERT_NAME)
	if zzz then
		zzz.Visible = state == "Sleep"
	end
	if alert then
		alert.Visible = state == "Alert"
	end
end

function GuardianModels.build(zone): Model
	local scale = 1 + (zone.index - 1) * 0.07 -- tinggi sekitar 10..14 stud
	local base = rgb(zone.wallRgb)
	local belly = rgb(zone.floorRgb):Lerp(Color3.new(1, 1, 1), 0.15)
	local accent = rgb(zone.accentRgb)
	local theme = THEMES[zone.guardian.id] or { feature = "horns" }

	local model = Instance.new("Model")
	model.Name = zone.guardian.name

	local legH = 3 * scale
	local bodySize = Vector3.new(8 * scale, 6 * scale, 10 * scale)
	local bodyY = legH + bodySize.Y / 2
	-- Depan guardian = -Z lokal (CFrame.lookAt menghadap target).
	local function at(x: number, y: number, z: number)
		return CFrame.new(x, y, z)
	end

	local body = part(model, "Body", Enum.PartType.Block, bodySize, at(0, bodyY, 0), base)
	part(
		model,
		"Belly",
		Enum.PartType.Ball,
		Vector3.new(7 * scale, 5 * scale, 8 * scale),
		at(0, bodyY - 0.8 * scale, -0.6 * scale),
		belly
	)
	-- kepala
	local headY = bodyY + bodySize.Y / 2 + 0.5 * scale
	part(
		model,
		"Head",
		Enum.PartType.Ball,
		Vector3.new(5.5 * scale, 5 * scale, 5.5 * scale),
		at(0, headY, -5 * scale),
		base:Lerp(accent, 0.15)
	)
	for _, side in { -1, 1 } do
		part(
			model,
			"Eye",
			Enum.PartType.Ball,
			Vector3.new(1.2 * scale, 1.2 * scale, 1.2 * scale),
			at(side * 1.5 * scale, headY + 0.6 * scale, -7.4 * scale),
			Color3.new(1, 1, 1)
		)
		part(
			model,
			"Pupil",
			Enum.PartType.Ball,
			Vector3.new(0.6 * scale, 0.6 * scale, 0.6 * scale),
			at(side * 1.5 * scale, headY + 0.6 * scale, -7.9 * scale),
			Color3.fromRGB(30, 20, 20)
		)
	end
	-- kaki
	for _, lx in { -1, 1 } do
		for _, lz in { -1, 1 } do
			part(
				model,
				"Leg",
				Enum.PartType.Block,
				Vector3.new(2.2 * scale, legH, 2.2 * scale),
				at(lx * 3 * scale, legH / 2, lz * 3.4 * scale),
				base:Lerp(Color3.new(0, 0, 0), 0.2)
			)
		end
	end

	-- fitur khas tema
	local feature = theme.feature
	if feature == "shell" then
		part(
			model,
			"Shell",
			Enum.PartType.Ball,
			Vector3.new(9 * scale, 7 * scale, 11 * scale),
			at(0, bodyY + 3 * scale, 0.5 * scale),
			accent:Lerp(base, 0.5)
		)
	elseif feature == "bulge" then
		part(
			model,
			"Bulge",
			Enum.PartType.Ball,
			Vector3.new(6 * scale, 4 * scale, 6 * scale),
			at(0, headY - 1 * scale, -3.5 * scale),
			belly
		)
	elseif feature == "vines" then
		for i = -1, 1 do
			part(
				model,
				"Vine",
				Enum.PartType.Cylinder,
				Vector3.new(7 * scale, 0.9 * scale, 0.9 * scale),
				at(i * 2.5 * scale, bodyY + 3.2 * scale, 1 * scale)
					* CFrame.Angles(0, math.rad(90), math.rad(20 * i)),
				accent
			)
		end
	elseif feature == "horns" then
		for _, side in { -1, 1 } do
			part(
				model,
				"Horn",
				Enum.PartType.Block,
				Vector3.new(1 * scale, 4 * scale, 1 * scale),
				at(side * 2.4 * scale, headY + 3.2 * scale, -5 * scale)
					* CFrame.Angles(0, 0, math.rad(-side * 18)),
				accent
			)
		end
	elseif feature == "claws" then
		for _, side in { -1, 1 } do
			part(
				model,
				"Claw",
				Enum.PartType.Block,
				Vector3.new(2 * scale, 2 * scale, 5 * scale),
				at(side * 5.2 * scale, bodyY - 0.5 * scale, -5 * scale),
				accent
			)
		end
	elseif feature == "spikes" then
		for i = -2, 2 do
			part(
				model,
				"Spike",
				Enum.PartType.Block,
				Vector3.new(1.2 * scale, 3 * scale, 1.2 * scale),
				at(0, bodyY + 3.6 * scale, i * 2.2 * scale)
					* CFrame.Angles(math.rad(10 * i), 0, math.rad(45)),
				accent
			)
		end
	elseif feature == "wings" then
		for _, side in { -1, 1 } do
			part(
				model,
				"Wing",
				Enum.PartType.Block,
				Vector3.new(7 * scale, 0.5 * scale, 6 * scale),
				at(side * 7 * scale, bodyY + 2 * scale, 0.5 * scale)
					* CFrame.Angles(0, 0, math.rad(side * 20)),
				accent
			)
		end
	elseif feature == "gears" then
		for _, side in { -1, 1 } do
			part(
				model,
				"Gear",
				Enum.PartType.Cylinder,
				Vector3.new(1 * scale, 4.5 * scale, 4.5 * scale),
				at(side * 4.6 * scale, bodyY + 1 * scale, 1 * scale),
				accent
			)
		end
	elseif feature == "eyes" then
		for i = -2, 2 do
			part(
				model,
				"ExtraEye",
				Enum.PartType.Ball,
				Vector3.new(1 * scale, 1 * scale, 1 * scale),
				at(i * 1.6 * scale, bodyY + 1.5 * scale, -5.3 * scale),
				accent
			)
		end
	end

	-- papan status (Zzz / !) di atas kepala
	local gui = Instance.new("BillboardGui")
	gui.Name = STATUS_NAME
	gui.Size = UDim2.fromOffset(90, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, headY + 5 * scale - bodyY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Adornee = body
	makeLabel(ZZZ_NAME, "Zzz", Color3.fromRGB(190, 220, 255), true).Parent = gui
	makeLabel(ALERT_NAME, "!", Color3.fromRGB(220, 50, 40), false).Parent = gui
	gui.Parent = body

	-- Pivot di tanah (bawah Body), supaya PivotTo(CFrame.new(x, 0, z)) menaruh guardian di lantai.
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -bodyY, 0)

	model:SetAttribute(Types.Attr.GuardianId, zone.guardian.id)
	model:SetAttribute(Types.Attr.ZoneIndex, zone.index)
	model:SetAttribute(Types.Attr.GuardianState, "Sleep")
	model:AddTag(Types.Tags.Guardian)
	return model
end

return GuardianModels
